#!/usr/bin/env python3
"""Compile production DLSS constants statements against real Godot/Streamline types.

CPU source-extraction harness, not a renderer/SDK runtime test. The renderer's
DLSS FOV statements, Parameters::fovy assignment, conversion helpers, and complete
slSetConstants block are copied verbatim at run time; a mock SDK function captures
the actual Constants argument. No installed SDK, GPU, generated engine headers,
or engine build is needed. Requires Python 3 and a C++17 compiler.
"""
import argparse
import os
from pathlib import Path
import subprocess
import tempfile


def block(text, marker):
    start = text.index(marker)
    brace = text.index("{", start)
    depth = 1
    end = brace + 1
    while depth:
        depth += (text[end] == "{") - (text[end] == "}")
        end += 1
    return text[start:end]


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("repo", type=Path)
    modes = p.add_mutually_exclusive_group(required=True)
    modes.add_argument("--check-fov", action="store_true")
    modes.add_argument("--check-basis", action="store_true")
    p.add_argument("--precision", choices=("single", "double"), default="single")
    args = p.parse_args()
    repo = args.repo.resolve()
    dlss = (repo / "servers/rendering/renderer_rd/effects/dlss.cpp").read_text()
    renderer = (repo / "servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp").read_text()
    dlss_path = renderer[renderer.index("} else if (p_scale_type == SCALE_3D_DLSS)"):]
    statements = []
    for prefix in ("real_t fov =", "real_t aspect =", "real_t fovy =", "params.fovy ="):
        matches = [line.strip() for line in dlss_path.splitlines() if line.strip().startswith(prefix)]
        if not matches:
            raise RuntimeError(f"Missing source statement: {prefix}")
        statements.append(matches[0])
    helpers = "\n\n".join(block(dlss, marker) for marker in (
        "static sl::float4x4 sl_make_identity_matrix()",
        "static sl::float4x4 sl_convert_matrix(",
        "static sl::float3 sl_convert_vector("))
    constants = block(dlss, "if (StreamlineContext::get().slSetConstants != nullptr)")
    template = Path(__file__).with_suffix(".cpp.in").read_text()
    source = template.replace("@HELPERS@", helpers).replace("@CONSTANTS@", constants).replace("@FOV@", "\n".join(statements))
    mode = "fov" if args.check_fov else "basis"
    print(f"Repository: {repo}", flush=True)
    print(f"Mode: {mode}; real_t: {args.precision}; CPU source-extraction harness with mock SDK capture", flush=True)
    compiler = os.environ.get("CXX", "g++")
    with tempfile.TemporaryDirectory(prefix="check_dlss_constants_") as temp:
        temp = Path(temp)
        cpp = temp / "check.cpp"
        cpp.write_text(source)
        executable = temp / "check"
        command = [compiler, "-std=c++17", "-O2", "-ffunction-sections", "-fdata-sections", "-Wl,--gc-sections", f"-I{repo}", f"-I{repo / 'platform/linuxbsd'}"]
        if args.precision == "double":
            command.append("-DREAL_T_IS_DOUBLE")
        command += [str(cpp), str(repo / "core/math/projection.cpp"), str(repo / "core/math/basis.cpp"), "-o", str(executable)]
        subprocess.run(command, check=True)
        return subprocess.run([str(executable), mode]).returncode


if __name__ == "__main__":
    raise SystemExit(main())
