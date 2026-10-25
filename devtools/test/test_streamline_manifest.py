#!/usr/bin/env python3
"""Offline regression tests for Streamline release selection and packaging."""

import copy
import importlib.util
import io
import tempfile
import unittest
import warnings
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("streamline_manifest", ROOT / "devtools/package/streamline_manifest.py")
MANIFEST = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MANIFEST)


class StreamlineManifestTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = (ROOT / "drivers/streamline/streamline_runtime.h").read_text(encoding="utf-8")

    def test_pinned_release_metadata_matches_compiled_headers(self):
        manifest = MANIFEST.load_manifest(ROOT)
        self.assertEqual(manifest["sdk_version"], "2.14.16")
        self.assertEqual(manifest["download_size"], 276016170)
        self.assertEqual(
            manifest["download_sha256"], "32041e51db0cab709a271b72a352281b690c2abbd669a827809401a5dd23956b"
        )
        self.assertEqual(len(manifest["runtime_files"]), 19)
        self.assertNotIn("sl.nvperf.dll", manifest["private_runtime_files"])
        self.assertEqual(set(manifest["runtime_files"]) - set(manifest["private_runtime_files"]), {"sl.nvperf.dll"})

    def test_mismatched_compiled_header_version_is_rejected(self):
        with self.assertRaisesRegex(ValueError, "versions differ"):
            MANIFEST.parse_manifest(self.source, "2.10.0")

    def test_metadata_drift_and_unpinned_urls_are_rejected(self):
        replacements = (
            ("streamline-sdk-v2.14.16.zip", "streamline-sdk-v2.10.0.zip"),
            ("releases/tag/v2.14.16", "releases/latest"),
            ("blob/v2.14.16/license.txt", "blob/main/license.txt"),
            ("276016170", "0"),
            ("276016170", "2147483648"),
            ("32041e51db0cab709a271b72a352281b690c2abbd669a827809401a5dd23956b", "not-a-digest"),
            ('"bin/x64/"', '"bin/x64/development/"'),
        )
        for old, new in replacements:
            with self.subTest(new=new), self.assertRaises(ValueError):
                MANIFEST.parse_manifest(self.source.replace(old, new), "2.14.16")

    def test_missing_feature_plugins_or_licenses_are_rejected(self):
        for filename in MANIFEST.REQUIRED_FILES:
            with self.subTest(filename=filename), self.assertRaisesRegex(ValueError, "omits"):
                MANIFEST.parse_manifest(self.source.replace('\t"' + filename + '",\n', ""), "2.14.16")

    def test_unsafe_or_duplicate_windows_filenames_are_rejected(self):
        for filename in ("../sl.extra.dll", "development/sl.extra.dll", "C:\\sl.extra.dll", "SL.DLSS.DLL"):
            with self.subTest(filename=filename), self.assertRaises(ValueError):
                MANIFEST.parse_manifest(self.source.replace('"sl.directsr.dll",', '"' + filename + '",'), "2.14.16")

    def make_archive(self, entries):
        stream = io.BytesIO()
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", UserWarning)
            with zipfile.ZipFile(stream, "w") as archive:
                for name, data in entries:
                    archive.writestr(name, data)
        return stream

    def test_complete_release_inventory_is_accepted(self):
        manifest = MANIFEST.load_manifest(ROOT)
        entries = [(manifest["zip_dir"] + name, b"fixture") for name in manifest["runtime_files"]]
        with zipfile.ZipFile(self.make_archive(entries)) as archive:
            MANIFEST.validate_archive_members(archive, manifest)

    def test_development_files_do_not_replace_missing_release_entries(self):
        manifest = MANIFEST.load_manifest(ROOT)
        entries = [(manifest["zip_dir"] + "development/" + name, b"fixture") for name in manifest["runtime_files"]]
        with zipfile.ZipFile(self.make_archive(entries)) as archive, self.assertRaisesRegex(ValueError, "Missing"):
            MANIFEST.validate_archive_members(archive, manifest)

    def test_empty_duplicate_and_missing_archive_entries_are_rejected(self):
        manifest = MANIFEST.load_manifest(ROOT)
        entries = [(manifest["zip_dir"] + name, b"fixture") for name in manifest["runtime_files"]]
        variants = (entries[1:], entries + entries[:1], [(entries[0][0], b"")] + entries[1:])
        for entries in variants:
            with zipfile.ZipFile(self.make_archive(entries)) as archive, self.assertRaises(ValueError):
                MANIFEST.validate_archive_members(archive, manifest)

    def test_changed_download_is_rejected_before_archive_access(self):
        manifest = copy.deepcopy(MANIFEST.load_manifest(ROOT))
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "download.zip"
            path.write_bytes(b"not-the-official-sdk")
            with self.assertRaisesRegex(ValueError, "size"):
                MANIFEST.validate_archive(path, manifest)
            manifest["download_size"] = path.stat().st_size
            with self.assertRaisesRegex(ValueError, "SHA-256"):
                MANIFEST.validate_archive(path, manifest)

    def make_vendored_sdk(self, directory):
        vendor_root = Path(directory) / "streamline"
        entries = (
            ("include/sl.h", b'#pragma once\r\n#include "sl_version.h"\r\n'),
            ("include/sl_version.h", b"#define SL_VERSION_MAJOR 2\r\n"),
            ("license.txt", b"SDK license fixture\r\n"),
        )
        for name, content in entries:
            path = vendor_root / ("LICENSE.txt" if name == "license.txt" else name)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content.replace(b"\r\n", b"\n"))
        return vendor_root, entries

    def test_vendored_sdk_accepts_newline_normalization(self):
        with tempfile.TemporaryDirectory() as directory:
            vendor_root, entries = self.make_vendored_sdk(directory)
            with zipfile.ZipFile(self.make_archive(entries)) as archive:
                MANIFEST.validate_vendored_sdk(archive, vendor_root)

    def test_vendored_sdk_rejects_missing_or_extra_headers(self):
        for missing in (True, False):
            with self.subTest(missing=missing), tempfile.TemporaryDirectory() as directory:
                vendor_root, entries = self.make_vendored_sdk(directory)
                if missing:
                    (vendor_root / "include/sl.h").unlink()
                else:
                    (vendor_root / "include/sl_old.h").write_bytes(b"old SDK header\n")
                with (
                    zipfile.ZipFile(self.make_archive(entries)) as archive,
                    self.assertRaisesRegex(ValueError, "inventory"),
                ):
                    MANIFEST.validate_vendored_sdk(archive, vendor_root)

    def test_vendored_sdk_rejects_tampered_header_or_license(self):
        for filename in ("include/sl.h", "LICENSE.txt"):
            with self.subTest(filename=filename), tempfile.TemporaryDirectory() as directory:
                vendor_root, entries = self.make_vendored_sdk(directory)
                (vendor_root / filename).write_bytes(b"changed SDK content\n")
                with (
                    zipfile.ZipFile(self.make_archive(entries)) as archive,
                    self.assertRaisesRegex(ValueError, "differs"),
                ):
                    MANIFEST.validate_vendored_sdk(archive, vendor_root)

    def test_vendored_sdk_rejects_missing_or_duplicate_archive_files(self):
        with tempfile.TemporaryDirectory() as directory:
            vendor_root, entries = self.make_vendored_sdk(directory)
            variants = (entries[1:], entries + entries[:1], entries[:-1], entries + entries[-1:])
            for variant in variants:
                with zipfile.ZipFile(self.make_archive(variant)) as archive, self.assertRaises(ValueError):
                    MANIFEST.validate_vendored_sdk(archive, vendor_root)

    def test_public_packages_accept_engine_and_physics_libraries(self):
        entries = (
            ("godot.windows.editor.x86_64.exe", b"fixture"),
            ("PhysXGpu_64.dll", b"fixture"),
            ("NvBlast.dll", b"fixture"),
            ("nvflow.dll", b"fixture"),
            ("GodotSharp/Api/Release/GodotSharp.dll", b"fixture"),
            ("templates/D3D12Core.x86_64.dll", b"fixture"),
            ("licenses/NVIDIA-STREAMLINE-SDK-HEADERS-LICENSE.txt", b"fixture"),
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "public.zip"
            path.write_bytes(self.make_archive(entries).getvalue())
            MANIFEST.validate_public_package(path)

    def test_public_packages_reject_runtime_dlls_in_any_folder_or_case(self):
        entries = (
            "sl.interposer.dll",
            "development/SL.DLSS.DLL",
            "GodotSharp/nvngx_dlss.dll",
            "templates/NvLowLatencyVk.dll",
            "templates\\development\\SL.extra.DLL",
        )
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "public.tpz"
            for filename in entries:
                path.write_bytes(self.make_archive([(filename, b"fixture")]).getvalue())
                with self.subTest(filename=filename), self.assertRaisesRegex(ValueError, "forbidden"):
                    MANIFEST.validate_public_package(path)


if __name__ == "__main__":
    unittest.main()
