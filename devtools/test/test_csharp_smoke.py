#!/usr/bin/env python3
"""Build and run the custom .NET/PhysX smoke project with local engine packages.

Run after building the mono editor and modules/mono/build_scripts/build_assemblies.py:
    python devtools/test/test_csharp_smoke.py --godot bin/<mono-editor> --dotnet dotnet

Projects, isolated NuGet packages, profiles and logs stay in devtools/out/.
The dummy renderer checks managed/native APIs, not rendering or GPU simulation.
"""

import argparse
import os
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

PROJECT = """config_version=5

[application]
config/name="Managed upgrade smoke"
run/main_scene="res://Main.tscn"
config/features=PackedStringArray("C#")

[dotnet]
project/assembly_name="ManagedSmoke"

[physics]
3d/physics_engine="PhysX"

[rendering]
renderer/rendering_method="gl_compatibility"
"""

SCENE = """[gd_scene load_steps=3 format=3]

[ext_resource type="Script" path="res://ManagedSmoke.cs" id="1"]

[sub_resource type="BoxShape3D" id="GroundShape"]
size = Vector3(10, 1, 10)

[node name="ManagedSmoke" type="Node3D"]
script = ExtResource("1")

[node name="Ground" type="StaticBody3D" parent="."]
position = Vector3(0, -1, 0)

[node name="CollisionShape3D" type="CollisionShape3D" parent="Ground"]
shape = SubResource("GroundShape")
"""


def executable(value):
    path = Path(value)
    if path.is_file():
        return path.resolve()
    located = shutil.which(value)
    if not located:
        raise RuntimeError(f"Executable not found: {value}")
    return Path(located).resolve()


def run(command, cwd, env, log, timeout):
    with log.open("w", encoding="utf-8") as output:
        result = subprocess.run(command, cwd=cwd, env=env, stdout=output, stderr=subprocess.STDOUT, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"Exit {result.returncode}: {command[0]}; see {log}")
    return log.read_text(encoding="utf-8", errors="replace")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", required=True, help="Built custom mono editor executable")
    parser.add_argument("--dotnet", default="dotnet", help=".NET SDK CLI name or path")
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    godot, dotnet = executable(args.godot), executable(args.dotnet)
    feed = root / "bin/GodotSharp/Tools/nupkgs"
    props = root / "modules/mono/SdkPackageVersions.props"
    if not props.is_file():
        raise RuntimeError("Generate mono glue and run build_assemblies.py first (missing SdkPackageVersions.props).")
    sdk_version = ET.parse(props).findtext(".//PackageVersion_Godot_NET_Sdk")
    target_framework = ET.parse(root / "modules/mono/glue/GodotSharp/GodotSharp/GodotSharp.csproj").findtext(
        ".//TargetFramework"
    )
    if not sdk_version or not target_framework:
        raise RuntimeError("Unable to read the built SDK version or GodotSharp target framework.")
    if not (feed / f"Godot.NET.Sdk.{sdk_version}.nupkg").is_file():
        raise RuntimeError(f"Missing local SDK package {sdk_version}; run build_assemblies.py first.")

    out = root / "devtools/out"
    out.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="csharp-smoke-", dir=out))
    print(f"Smoke artifacts: {work}", flush=True)
    env = os.environ.copy()
    env.update({
        "DOTNET_ROOT": str(dotnet.parent),
        "PATH": str(dotnet.parent) + os.pathsep + env.get("PATH", ""),
        "DOTNET_CLI_HOME": str(work / "dotnet-home"),
        "DOTNET_CLI_TELEMETRY_OPTOUT": "1",
        "DOTNET_GENERATE_ASPNET_CERTIFICATE": "false",
        "DOTNET_PROCESSOR_COUNT": "1",
        "DOTNET_CLI_USE_MSBUILD_SERVER": "0",
        "MSBUILDDISABLENODEREUSE": "1",
        "NUGET_PACKAGES": str(work / "packages"),
        "XDG_CACHE_HOME": str(work / "profile/cache"),
        "XDG_CONFIG_HOME": str(work / "profile/config"),
        "XDG_DATA_HOME": str(work / "profile/data"),
        "APPDATA": str(work / "profile/appdata"),
        "LOCALAPPDATA": str(work / "profile/localappdata"),
    })
    for key in ("XDG_CACHE_HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "APPDATA", "LOCALAPPDATA"):
        Path(env[key]).mkdir(parents=True, exist_ok=True)
    version = run([str(godot), "--version"], root, env, work / "version.log", 30).strip()
    if ".mono." not in version:
        raise RuntimeError(f"Select a mono editor with --godot; got {version}")

    (work / "project.godot").write_text(PROJECT, encoding="utf-8")
    (work / "Main.tscn").write_text(SCENE, encoding="utf-8")
    shutil.copyfile(Path(__file__).with_name("csharp_smoke.cs"), work / "ManagedSmoke.cs")
    project = ET.Element("Project", Sdk=f"Godot.NET.Sdk/{sdk_version}")
    group = ET.SubElement(project, "PropertyGroup")
    ET.SubElement(group, "TargetFramework").text = target_framework
    ET.SubElement(group, "EnableDynamicLoading").text = "true"
    ET.ElementTree(project).write(work / "ManagedSmoke.csproj", encoding="utf-8", xml_declaration=True)
    config = ET.Element("configuration")
    sources = ET.SubElement(config, "packageSources")
    ET.SubElement(sources, "clear")
    ET.SubElement(sources, "add", key="custom-engine", value=str(feed))
    ET.ElementTree(config).write(work / "NuGet.Config", encoding="utf-8", xml_declaration=True)

    run(
        [
            str(dotnet),
            "build",
            "ManagedSmoke.csproj",
            "-m:1",
            "-p:UseSharedCompilation=false",
            "-p:RestoreDisableParallel=true",
            "--nologo",
        ],
        work,
        env,
        work / "build.log",
        300,
    )
    runtime = run(
        [
            str(godot),
            "--headless",
            "--verbose",
            "--rendering-driver",
            "dummy",
            "--path",
            str(work),
            "--fixed-fps",
            "60",
            "--quit-after",
            "120",
        ],
        work,
        env,
        work / "runtime.log",
        30,
    )
    marker = "CSHARP_PHYSX_SMOKE_PASS typed_and_dictionary_ray_queries custom_types=4"
    if marker not in runtime or "ERROR:" in runtime or "CSHARP_PHYSX_SMOKE_FAIL" in runtime:
        raise RuntimeError(f"Managed physics assertions failed or logged errors; see {work / 'runtime.log'}")
    if not re.search(r"PhysX \d+\.\d+\.\d+ initialized", runtime) or ".NET: GodotPlugins initialized" not in runtime:
        raise RuntimeError(f"PhysX/managed initialization not confirmed; see {work / 'runtime.log'}")
    print(f"PASS {version}; SDK {sdk_version}, {target_framework}", flush=True)
    print(marker, flush=True)
    print("Dummy renderer only; Windows, GPU rendering and exported games require separate verification.", flush=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError, subprocess.TimeoutExpired, ET.ParseError) as error:
        raise SystemExit(str(error))
