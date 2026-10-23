"""Launch the actual Windows/Vulkan renderer; never permits headless/mock fallback."""
import argparse
import ctypes
import hashlib
import json
import os
import shutil
from pathlib import Path
import subprocess
import time
import zipfile

ROOT = Path(__file__).resolve().parent

def sdk_modules(process):
    if os.name != "nt":
        return []
    from ctypes import wintypes
    modules = (wintypes.HMODULE * 1024)()
    needed = wintypes.DWORD()
    enum = ctypes.windll.psapi.EnumProcessModulesEx
    enum.argtypes = [wintypes.HANDLE, ctypes.c_void_p, wintypes.DWORD, ctypes.POINTER(wintypes.DWORD), wintypes.DWORD]
    get_name = ctypes.windll.psapi.GetModuleFileNameExW
    get_name.argtypes = [wintypes.HANDLE, wintypes.HMODULE, wintypes.LPWSTR, wintypes.DWORD]
    if not enum(int(process._handle), modules, ctypes.sizeof(modules), ctypes.byref(needed), 3):
        return []
    found = []
    for module in modules[:min(needed.value // ctypes.sizeof(wintypes.HMODULE), len(modules))]:
        name = ctypes.create_unicode_buffer(32768)
        if get_name(int(process._handle), module, name, len(name)):
            path = Path(name.value)
            if path.name.lower().startswith(("sl.", "nvngx_", "nvlowlatency")):
                found.append(path)
    return found

def setup_sdk():
    archive = ROOT.parent / "sdk" / "streamline-sdk-v2.10.0.zip"
    hashes = {"archive_sha256": hashlib.sha256(archive.read_bytes()).hexdigest(), "files": {}}
    with zipfile.ZipFile(archive) as sdk:
        for name in sdk.namelist():
            if name.startswith("bin/x64/") and name.count("/") == 2 and name.endswith(".dll"):
                data = sdk.read(name)
                dest = ROOT / "bin" / Path(name).name
                dest.write_bytes(data)
                hashes["files"][dest.name] = hashlib.sha256(data).hexdigest()
    (ROOT / "logs" / "sdk-manifest.json").write_text(json.dumps(hashes, indent=2))

def run(variant, mode, suite):
    executable = ROOT / "bin" / f"{variant}.exe"
    out = ROOT / ("captures-smoke" if suite == "smoke" else "captures") / variant / mode
    out.mkdir(parents=True, exist_ok=True)
    for name in ("project.godot", "main.tscn", "validate.gd"):
        shutil.copy2(ROOT / "project" / name, ROOT / "bin" / name)
    (ROOT / "bin" / ".godot").mkdir(exist_ok=True)
    (ROOT / "bin" / ".godot" / "global_script_class_cache.cfg").write_text("list=[]\n", encoding="utf-8")
    command = [str(executable), "--rendering-method", "forward_plus",
               "--rendering-driver", "vulkan", "--audio-driver", "Dummy", "--disable-crash-handler", "--verbose", "--",
               "--mode", mode, "--output", str(out), "--suite", suite]
    env = dict(os.environ, GODOT_DLSS_CAPTURE="1")
    start = time.time()
    result = {"variant": variant, "mode": mode, "suite": suite, "command": command,
              "exe_sha256": hashlib.sha256(executable.read_bytes()).hexdigest(), "started_unix": start}
    with (out / "runtime.log").open("w", encoding="utf-8") as log:
        process = subprocess.Popen(command, cwd=ROOT / "bin", env=env, stdin=subprocess.DEVNULL, stdout=log, stderr=subprocess.STDOUT,
                                   creationflags=subprocess.CREATE_NO_WINDOW if os.name == "nt" else 0)
        loaded = {}
        while process.poll() is None and time.time() - start < 300:
            for path in sdk_modules(process):
                if str(path) not in loaded:
                    try:
                        loaded[str(path)] = {"name": path.name, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}
                    except OSError:
                        pass
            time.sleep(0.5)
        if process.poll() is None:
            process.kill()
            process.wait()
            result["timeout"] = True
        result["exit_code"] = process.returncode
        result["loaded_sdk_modules"] = list(loaded.values())
    result["elapsed_seconds"] = time.time() - start
    (out / "run.json").write_text(json.dumps(result, indent=2))
    print(json.dumps({k: result[k] for k in ("variant", "mode", "suite", "exit_code", "elapsed_seconds")}), flush=True)
    return result["exit_code"]

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("variant", choices=["baseline", "pr17", "pr18", "both"])
    parser.add_argument("--mode", choices=["DLAA", "SR", "RR", "FG", "all"], default="all")
    parser.add_argument("--suite", choices=["smoke", "full"], default="full")
    parser.add_argument("--setup-sdk", action="store_true")
    args = parser.parse_args()
    if args.setup_sdk:
        setup_sdk()
    failures = []
    for mode in (["DLAA", "SR", "RR", "FG"] if args.mode == "all" else [args.mode]):
        code = run(args.variant, mode, args.suite)
        if code:
            failures.append((mode, code))
    if failures:
        raise SystemExit(1)
