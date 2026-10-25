#!/usr/bin/env python3
"""Run fork API/serialization smoke checks without a GPU.

Unpacked project with an editor:
  python devtools/test/upgrade_smoke.py --godot bin/<editor>

Real exported PCK with a production template (no unsafe path overrides):
  python devtools/test/upgrade_smoke.py --export-editor bin/<editor> --template bin/<template>

Use --require-physx/--require-blast/--require-flow/--require-mono for builds that
include those modules. Optional modules otherwise produce explicit SKIP lines.
The PCK path exercises normal template startup, GDScript execution and resource
serialization; it does not validate GPU rendering, DLSS/Reflex DLL loading,
baking, C# project export, or Windows redistribution. Run the existing Windows
smoke and packaging tests for those paths.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path


def _project(project: Path) -> None:
    (project / "project.godot").write_text(
        'config_version=5\n[application]\nconfig/name="Fork API smoke"\n'
        'run/main_scene="res://main.tscn"\n'
        "[debug]\nfile_logging/enable_file_logging=false\n",
        encoding="utf-8",
    )
    (project / "main.tscn").write_text(
        "[gd_scene load_steps=2 format=3]\n\n"
        '[ext_resource type="Script" path="res://integration_smoke.gd" id="1"]\n\n'
        '[node name="IntegrationSmoke" type="Node"]\nscript = ExtResource("1")\n',
        encoding="utf-8",
    )
    shutil.copyfile(Path(__file__).with_name("integration_smoke.gd"), project / "integration_smoke.gd")


def _environment(profile: Path) -> dict[str, str]:
    # Keep user:// and editor configuration/cache away from real user profiles.
    # Preserve PATH, proxy settings, CA trust and SDK-specific runtime selectors.
    env = os.environ.copy()
    for key in ("XDG_DATA_HOME", "XDG_CONFIG_HOME", "XDG_CACHE_HOME", "APPDATA", "LOCALAPPDATA"):
        directory = profile / key.lower()
        directory.mkdir(parents=True, exist_ok=True)
        env[key] = str(directory)
    return env


def _run(
    command: list[str], log_path: Path, cwd: Path, env: dict[str, str], timeout: int
) -> subprocess.CompletedProcess[str] | None:
    try:
        result = subprocess.run(
            command,
            cwd=cwd,
            env=env,
            encoding="utf-8",
            errors="replace",
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as error:
        raw = error.stdout or ""
        text = raw.decode("utf-8", errors="replace") if isinstance(raw, bytes) else raw
        log_path.write_text(text, encoding="utf-8")
        print(f"FAIL: test process timed out; log: {log_path}")
        return None
    log_path.write_text(result.stdout, encoding="utf-8")
    print(result.stdout, end="")
    return result


def _copy_runtime(template: Path, game: Path) -> Path:
    executable = game / ("smoke.exe" if os.name == "nt" else "smoke")
    shutil.copy2(template, executable)
    # PhysX/Blast/Flow use sibling DLLs/ELF shared objects. Only copy native
    # siblings, not an editor or unrelated managed/tooling directories.
    for library in template.parent.iterdir():
        if library.is_file() and (
            library.suffix.lower() == ".dll" or library.name.endswith(".so") or ".so." in library.name
        ):
            shutil.copy2(library, game / library.name)
    return executable


def _preset(project: Path, template: Path) -> None:
    platform = "Windows Desktop" if os.name == "nt" else "Linux"
    template_path = json.dumps(template.as_posix())
    (project / "export_presets.cfg").write_text(
        '[preset.0]\nname="Smoke"\n'
        f'platform="{platform}"\n'
        'runnable=true\nexport_filter="all_resources"\n'
        'include_filter=""\nexclude_filter=""\n'
        "[preset.0.options]\n"
        f"custom_template/release={template_path}\ncustom_template/debug={template_path}\n",
        encoding="utf-8",
    )


def _has_errors(output: str) -> bool:
    plain = re.sub(r"\x1b\[[0-9;]*[mK]", "", output)
    return re.search(r"(?m)^\s*(?:SCRIPT ERROR:|ERROR:|UPGRADE_SMOKE FAIL)", plain) is not None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--godot", type=Path, help="built editor; runs the unpacked project")
    parser.add_argument("--export-editor", type=Path, help="editor used to produce a real PCK")
    parser.add_argument("--template", type=Path, help="native template executable (not its Windows console wrapper)")
    parser.add_argument("--timeout", type=int, default=120)
    parser.add_argument("--output-dir", type=Path, default=Path(__file__).resolve().parents[1] / "out/upgrade-smoke")
    for name in ("physx", "blast", "flow", "mono"):
        parser.add_argument(f"--require-{name}", action="store_true")
    args = parser.parse_args()
    if args.godot:
        if args.export_editor or args.template:
            parser.error("choose --godot or the --export-editor/--template pair")
    elif not (args.export_editor and args.template):
        parser.error("provide --godot, or both --export-editor and --template")
    for executable in (args.godot, args.export_editor, args.template):
        if executable and not executable.is_file():
            parser.error(f"executable does not exist: {executable}")
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    log_path = output / "integration_smoke.log"
    with tempfile.TemporaryDirectory(prefix="case-", dir=output) as temp:
        case = Path(temp)
        project = case / "project"
        project.mkdir()
        _project(project)
        env = _environment(case / "profile")
        if args.template:
            template = args.template.resolve()
            editor = args.export_editor.resolve()
            game = case / "game"
            game.mkdir()
            executable = _copy_runtime(template, game)
            _preset(project, template)
            pck = game / "smoke.pck"
            export_log = output / "pack_export.log"
            exported = _run(
                [
                    str(editor),
                    "--headless",
                    "--rendering-driver",
                    "dummy",
                    "--path",
                    str(project),
                    "--export-pack",
                    "Smoke",
                    str(pck),
                ],
                export_log,
                project,
                env,
                args.timeout,
            )
            if exported is None:
                return 1
            if exported.returncode or _has_errors(exported.stdout) or not pck.is_file() or pck.stat().st_size == 0:
                print(f"FAIL: PCK export did not succeed; log: {export_log}")
                return 1
            # Production templates reject --path/--script/--main-pack overrides.
            # Use the normal executable-name-matched PCK autoload from game/.
            command = [str(executable), "--headless", "--rendering-driver", "dummy", "--"]
            cwd = game
            label = "production PCK API smoke"
        else:
            command = [
                str(args.godot.resolve()),
                "--headless",
                "--rendering-driver",
                "dummy",
                "--path",
                str(project),
                "--",
            ]
            cwd = project
            label = "editor project API smoke"
        command += [
            f"--require-{name}" for name in ("physx", "blast", "flow", "mono") if getattr(args, f"require_{name}")
        ]
        result = _run(command, log_path, cwd, env, args.timeout)
        if result is None:
            return 1
        errors = _has_errors(result.stdout)
        passed = (
            result.returncode == 0
            and not errors
            and re.search(r"(?m)^UPGRADE_SMOKE PASS checks=\d+\s*$", result.stdout)
        )
        print(f"{'PASS' if passed else 'FAIL'}: {label}; log: {log_path}")
        return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
