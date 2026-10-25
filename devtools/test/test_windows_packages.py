#!/usr/bin/env python3
"""Run the real Windows packaging scripts in isolated Linux PowerShell fixtures.

The fixture executables only print a version and every DLL contains text. These
tests verify packaging, not Windows executables or NVIDIA runtime behavior.
Set PWSH to a PowerShell 7 executable, or put pwsh on PATH.
"""

import importlib.util
import os
import shutil
import subprocess
import tempfile
import unittest
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PWSH = os.environ.get("PWSH") or shutil.which("pwsh")
SPEC = importlib.util.spec_from_file_location("streamline_manifest", ROOT / "devtools/package/streamline_manifest.py")
MANIFEST = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MANIFEST)
PHYSICS_FILES = (
    "PhysXGpu_64.dll",
    "NvBlast.dll",
    "NvBlastGlobals.dll",
    "NvBlastExtAuthoring.dll",
    "NvBlastExtShaders.dll",
    "nvflow.dll",
    "nvflowext.dll",
)


@unittest.skipUnless(os.name == "posix" and PWSH, "requires Linux/Unix and PowerShell 7 (set PWSH)")
class WindowsPackageFixtureTest(unittest.TestCase):
    def setUp(self):
        output = ROOT / "devtools/out/package-fixtures"
        output.mkdir(parents=True, exist_ok=True)
        self.directory = tempfile.TemporaryDirectory(prefix="fixture-", dir=output)
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name) / "source with spaces"
        self.env = os.environ.copy()
        for name, suffix in (("XDG_CACHE_HOME", "cache"), ("XDG_CONFIG_HOME", "config"), ("XDG_DATA_HOME", "data")):
            self.env[name] = str(Path(self.directory.name) / suffix)
        self.manifest = MANIFEST.load_manifest(ROOT)
        for name in (
            "devtools/package/package_editor_win64.ps1",
            "devtools/package/package_templates_win64.ps1",
            "devtools/package/streamline_manifest.py",
            "drivers/streamline/streamline_runtime.h",
            "thirdparty/streamline/include/sl_version.h",
            "thirdparty/streamline/LICENSE.txt",
        ):
            destination = self.root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, destination)
        for name in (
            "LICENSE.txt",
            "COPYRIGHT.txt",
            "THIRD_PARTY_LICENSES.md",
            "modules/godot_physx/PHYSX-LICENSE.md",
            "misc/dist/licenses/FIXTURE-LICENSE.txt",
            "bin/GodotSharp/Api/Release/GodotSharp.dll",
        ):
            self.write(name)
        self.write("CUSTOM_VERSION", "0.7.3\n")
        self.write("version.py", 'major = 4\nminor = 8\nstatus = "beta"\n')
        for name in PHYSICS_FILES + ("D3D12Core.dll", "d3d12SDKLayers.dll"):
            self.write("bin/" + name)
        for mono in (False, True):
            suffix = ".mono" if mono else ""
            version = "4.8.beta" + suffix + ".custom_build.fixture"
            for target in ("editor", "template_release", "template_debug"):
                for console in ("", ".console"):
                    path = self.write(
                        "bin/godot.windows." + target + ".x86_64" + suffix + console + ".exe",
                        "#!/bin/sh\nprintf '%s\\n' '" + version + "'\n",
                    )
                    path.chmod(0o755)

    def write(self, name, text="Packaging fixture only; not a binary.\n"):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text, encoding="utf-8")
        return path

    def run_package(self, name, *options):
        return subprocess.run(
            [
                PWSH,
                "-NoLogo",
                "-NoProfile",
                "-NonInteractive",
                "-File",
                str(self.root / "devtools/package" / name),
                *options,
            ],
            cwd=self.root,
            env=self.env,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=90,
        )

    def assert_safe_paths(self, names):
        self.assertTrue(names)
        for name in names:
            self.assertNotIn("\\", name)
            self.assertFalse(name.startswith((".", "/")), name)

    def test_powershell_package_sources_parse(self):
        for script in self.root.glob("devtools/package/*.ps1"):
            with self.subTest(script=script.name):
                command = (
                    "$errors = $null; "
                    "[System.Management.Automation.Language.Parser]::ParseFile("
                    "'" + str(script).replace("'", "''") + "', [ref]$null, [ref]$errors) | Out-Null; "
                    "if ($errors.Count) { $errors | Out-String | Write-Error; exit 1 }"
                )
                result = subprocess.run(
                    [PWSH, "-NoLogo", "-NoProfile", "-NonInteractive", "-Command", command],
                    env=self.env,
                    text=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    timeout=30,
                )
                self.assertEqual(result.returncode, 0, result.stdout)

    def test_public_standard_and_mono_editor_archives(self):
        # Even installed NVIDIA files in bin/ must not leak into public zips.
        for name in self.manifest["runtime_files"]:
            self.write("bin/" + name)
        for mono in (False, True):
            with self.subTest(mono=mono):
                options = ("-Mono",) if mono else ()
                result = self.run_package("package_editor_win64.ps1", *options)
                self.assertEqual(result.returncode, 0, result.stdout)
                suffix = "_mono" if mono else ""
                path = (
                    self.root
                    / "dist"
                    / ("godot_4.8-nvidia-rt-dlss-physx_v0.7.3-editor_windows_amd64" + suffix + ".zip")
                )
                self.assertTrue(path.is_file(), result.stdout)
                MANIFEST.validate_public_package(path)
                with zipfile.ZipFile(path) as archive:
                    names = archive.namelist()
                    self.assert_safe_paths(names)
                    self.assertTrue(set(PHYSICS_FILES).issubset(names))
                    flavor = ".mono" if mono else ""
                    self.assertIn("godot.windows.editor.x86_64" + flavor + ".exe", names)
                    self.assertIn("licenses/NVIDIA-STREAMLINE-SDK-HEADERS-LICENSE.txt", names)
                    notice = archive.read("NVIDIA_DLSS_NOT_INCLUDED_README.txt").decode("utf-8-sig")
                    self.assertIn(self.manifest["sdk_version"], notice)
                    self.assertIn(self.manifest["release_url"], notice)
                    self.assertEqual("GodotSharp/Api/Release/GodotSharp.dll" in names, mono)

    def test_public_standard_and_mono_template_archives(self):
        for name in self.manifest["runtime_files"]:
            self.write("bin/" + name)
        for mono in (False, True):
            with self.subTest(mono=mono):
                result = self.run_package("package_templates_win64.ps1", *(("-Mono",) if mono else ()))
                self.assertEqual(result.returncode, 0, result.stdout)
                suffix = "_mono" if mono else ""
                name = "godot_4.8-nvidia-rt-dlss-physx_v0.7.3-export_templates_windows_amd64" + suffix + ".tpz"
                path = self.root / "dist" / name
                self.assertTrue(path.is_file(), result.stdout)
                MANIFEST.validate_public_package(path)
                with zipfile.ZipFile(path) as archive:
                    names = archive.namelist()
                    self.assert_safe_paths(names)
                    self.assertTrue(all(name.startswith("templates/") for name in names))
                    expected = "4.8.beta" + (".mono" if mono else "")
                    self.assertEqual(archive.read("templates/version.txt").decode("ascii"), expected)
                    for flavor in ("debug", "release"):
                        self.assertIn("templates/windows_" + flavor + "_x86_64.exe", names)
                        self.assertIn("templates/windows_" + flavor + "_x86_64_console.exe", names)
                    self.assertIn("templates/D3D12Core.x86_64.dll", names)
                    self.assertFalse(any(Path(name).name in PHYSICS_FILES for name in names))

    def test_private_editor_uses_allowlist_and_omits_nvperf_and_extra_plugins(self):
        for name in self.manifest["runtime_files"] + ["sl.extra.dll", "nvngx_untracked.dll"]:
            self.write("bin/" + name)
        self.write("bin/development/sl.debug.dll")
        result = self.run_package("package_editor_win64.ps1", "-WithNvidiaRuntime")
        self.assertEqual(result.returncode, 0, result.stdout)
        paths = list((self.root / "dist").glob("*_PRIVATE.zip"))
        self.assertEqual(len(paths), 1, result.stdout)
        with zipfile.ZipFile(paths[0]) as archive:
            names = archive.namelist()
            self.assert_safe_paths(names)
            self.assertTrue(set(self.manifest["private_runtime_files"]).issubset(names))
            for excluded in ("sl.nvperf.dll", "sl.extra.dll", "nvngx_untracked.dll", "development/sl.debug.dll"):
                self.assertNotIn(excluded, names)
            self.assertNotIn("NVIDIA_DLSS_NOT_INCLUDED_README.txt", names)

    def test_missing_blast_or_flow_prevents_editor_package(self):
        for missing in ("NvBlast.dll", "nvflow.dll"):
            with self.subTest(missing=missing):
                (self.root / "bin" / missing).unlink()
                result = self.run_package("package_editor_win64.ps1")
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertIn(missing, result.stdout)
                self.assertFalse(list((self.root / "dist").glob("*.zip")))
                self.write("bin/" + missing)

    def test_missing_private_runtime_prevents_private_package(self):
        for name in self.manifest["private_runtime_files"]:
            if name != "sl.dlss_g.dll":
                self.write("bin/" + name)
        result = self.run_package("package_editor_win64.ps1", "-WithNvidiaRuntime")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("sl.dlss_g.dll", result.stdout)
        self.assertFalse(list((self.root / "dist").glob("*.zip")))

    def test_nested_nvidia_dll_in_mono_output_rejects_and_deletes_public_archive(self):
        self.write("bin/GodotSharp/development/SL.DLSS.DLL")
        result = self.run_package("package_editor_win64.ps1", "-Mono")
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("forbidden", result.stdout)
        self.assertFalse(list((self.root / "dist").glob("*.zip")))


if __name__ == "__main__":
    unittest.main()
