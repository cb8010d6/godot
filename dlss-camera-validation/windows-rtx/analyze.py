"""Check real SDK boundary captures against camera projection and independent rotations."""
import argparse
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TOLERANCE = 2e-5

def near(a, b):
    if isinstance(a, list):
        return len(a) == len(b) and all(near(x, y) for x, y in zip(a, b))
    return abs(a - b) <= TOLERANCE

def basis_geometry(sample):
    axes = [sample[k] for k in ("right", "up", "forward")]
    dot = lambda a, b: sum(x * y for x, y in zip(a, b))
    a, b, f = axes
    cross = [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
    return all(near(dot(v, v), 1.0) for v in axes) and all(near(dot(axes[i], axes[j]), 0.0) for i, j in ((0, 1), (0, 2), (1, 2))) and near(cross, [-n for n in f])

def rotate(v, axis, angle):
    length = math.sqrt(sum(x * x for x in axis))
    x, y, z = [n / length for n in axis]
    cross = [y * v[2] - z * v[1], z * v[0] - x * v[2], x * v[1] - y * v[0]]
    dot = sum(a * b for a, b in zip([x, y, z], v))
    return [v[i] * math.cos(angle) + cross[i] * math.sin(angle) + [x, y, z][i] * dot * (1 - math.cos(angle)) for i in range(3)]

def independent_basis(case_id):
    specs = {"basis_yaw90": ([0, 1, 0], math.pi / 2), "basis_pitch90": ([1, 0, 0], math.pi / 2),
             "basis_roll90": ([0, 0, 1], math.pi / 2), "basis_axis123": ([1, 2, 3], 0.73)}
    axes = {"forward": [0, 0, -1], "up": [0, 1, 0], "right": [1, 0, 0]}
    if case_id not in specs:
        return axes
    axis, angle = specs[case_id]
    return {k: rotate(v, axis, angle) for k, v in axes.items()}

def analyze(folder):
    run = json.loads((folder / "run.json").read_text())
    metadata = json.loads((folder / "metadata.json").read_text()) if (folder / "metadata.json").exists() else {}
    cases = json.loads((folder / "cases.json").read_text()) if (folder / "cases.json").exists() else []
    text = (folder / "runtime.log").read_text(encoding="utf-8", errors="replace")
    records = []
    invalid = []
    for line in text.splitlines():
        if "[DLSS-VALIDATION] " in line:
            try:
                records.append(json.loads(line.split("[DLSS-VALIDATION] ", 1)[1]))
            except json.JSONDecodeError:
                invalid.append(line)
    constants = [r for r in records if r["stage"] == "constants"]
    evaluated = {r["seq"]: r for r in records if r["stage"] == "evaluate"}
    fg_states = {r["seq"]: r for r in records if r["stage"] == "fg_state"}
    errors = [line for line in text.splitlines() if "ERROR:" in line or "SCRIPT ERROR:" in line]
    summary = {"variant": run["variant"], "mode": run["mode"], "exit_code": run["exit_code"],
               "metadata": metadata, "runtime_errors": errors, "malformed_records": invalid, "constant_records": len(constants),
               "sdk_failures": [r for r in records if r.get("result") != 0], "cases": []}
    diagnostics = [line for line in text.splitlines() if "needs to have the same texture format as the uniform" in line or "OpTypeForwardPointer is not supported yet" in line]
    summary["existing_verbose_diagnostics"] = {"count": len(diagnostics), "unique": sorted(set(diagnostics))}
    for case in cases:
        samples = [r for r in constants if case["start_frame"] < r["frame"] <= case["end_frame"] and r["width"] == case["width"] and r["height"] == case["height"]]
        basis = independent_basis(case["id"])
        expected_fov = math.pi / 2 if case["keep_aspect"] == 1 else 2 * math.atan(case["height"] / case["width"])
        projection_ok = near(case["expected_fov"], expected_fov)
        camera_basis_ok = all(near(case["expected_" + key], value) for key, value in basis.items())
        good_eval = [r for r in samples if evaluated.get(r["seq"], {}).get("result") == 0]
        fg = [fg_states[r["seq"]] for r in samples if r["seq"] in fg_states]
        row = {"id": case["id"], "samples": len(samples), "expected_fov": expected_fov,
               "actual_fov": samples[-1]["fov"] if samples else None,
               "expected_forward": basis["forward"], "actual_forward": samples[-1]["forward"] if samples else None,
               "reference_projection_ok": projection_ok, "reference_basis_ok": camera_basis_ok,
               "fov_ok": bool(samples) and projection_ok and all(near(r["fov"], expected_fov) for r in samples),
               "basis_ok": bool(samples) and camera_basis_ok and all(all(near(r[key], value) for key, value in basis.items()) for r in samples),
               "basis_geometry_ok": bool(samples) and all(basis_geometry(r) for r in samples),
               "position_ok": bool(samples) and all(near(r["position"], [3, -7, 11]) for r in samples),
               "aspect_ok": bool(samples) and all(near(r["aspect"], case["width"] / case["height"]) for r in samples),
               "sdk_constants_ok": len(samples) >= 6 and all(r["result"] == 0 for r in samples),
               "sdk_evaluate_ok": len(good_eval) == len(samples) and len(samples) >= 6,
               "selected_mode_ok": bool(samples) and all(r["mode"] == (6 if run["mode"] == "DLAA" else 3) for r in samples),
               "rr_active": bool(samples) and all(r["rr"] for r in samples),
               "fg_active": len(fg) >= 6 and all(s["result"] == 0 and s["status"] == 0 and s["max_generated"] >= 1 for s in fg) and sum(s["presented"] for s in fg) > len(fg),
               "fg_state_samples": fg, "screenshot_ok": case["screenshot_result"] == 0 and (folder / (case["id"] + ".png")).exists()}
        summary["cases"].append(row)
    summary["runtime_complete"] = run["exit_code"] == 0 and len(cases) == (2 if run["suite"] == "smoke" else 13) and not errors and not invalid and not summary["sdk_failures"]
    (folder / "analysis.json").write_text(json.dumps(summary, indent=2))
    compact = {k: summary[k] for k in ("variant", "mode", "exit_code", "runtime_complete", "constant_records")}
    compact["case_count"] = len(cases)
    compact["fov_pass"] = sum(c["fov_ok"] for c in summary["cases"])
    compact["basis_pass"] = sum(c["basis_ok"] for c in summary["cases"])
    compact["sdk_evaluate_pass"] = sum(c["sdk_evaluate_ok"] for c in summary["cases"])
    compact["errors"] = errors[:5]
    print(json.dumps(compact))
    return summary

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("folders", nargs="*")
    args = parser.parse_args()
    for folder in ([Path(p) for p in args.folders] if args.folders else sorted((ROOT / "captures").glob("*/*"))):
        if (folder / "run.json").exists():
            analyze(folder)
