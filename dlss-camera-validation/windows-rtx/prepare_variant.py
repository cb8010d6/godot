"""Prepare a local, instrumented renderer from exact PR/base blobs. No git writes."""
import argparse
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent
SOURCE = ROOT.parent / "source"
BASE = "135dff3887a3d2ccf45cafbd9bdffa7b718e1e76"
REFS = {"baseline": BASE, "pr17": "2ccecd2d10d2304e442dc8fb94a6878cd61d08be", "pr18": "0b50d914deb01928f4985b555e4765f8fa16b43b"}
DLSS = "servers/rendering/renderer_rd/effects/dlss.cpp"
FORWARD = "servers/rendering/renderer_rd/forward_clustered/render_forward_clustered.cpp"

def blob(ref, name):
    return subprocess.check_output(["git", "show", f"{ref}:{name}"], cwd=SOURCE).decode()

def replace_once(text, old, new):
    assert text.count(old) == 1, (old, text.count(old))
    return text.replace(old, new, 1)

HELPER = r'''
// [DLSS-VALIDATION] Local capture only. Calls the real SDK without changing arguments.
#include "core/config/engine.h"
#include "core/io/json.h"
#include "core/os/os.h"
static Array dlss_validation_vector(const sl::float3 &p_vector) {
	Array a;
	a.push_back(p_vector.x);
	a.push_back(p_vector.y);
	a.push_back(p_vector.z);
	return a;
}
'''

CONSTANTS = r'''
		if (dlss_validation_capture) {
			Dictionary capture;
			capture["stage"] = "constants";
			capture["seq"] = dlss_validation_seq;
			capture["frame"] = Engine::get_singleton()->get_frames_drawn();
			capture["viewport"] = (int)(unsigned int)context->viewport;
			capture["api"] = RD::get_singleton()->get_device_api_name();
			capture["width"] = context->currentDlssOptions.outputWidth;
			capture["height"] = context->currentDlssOptions.outputHeight;
			capture["mode"] = (int)context->currentDlssOptions.mode;
			capture["rr"] = use_dlss_rr;
			capture["fg_requested"] = p_params.dlss_g;
			capture["fov"] = context->constants.cameraFOV;
			capture["aspect"] = context->constants.cameraAspectRatio;
			capture["position"] = dlss_validation_vector(context->constants.cameraPos);
			capture["forward"] = dlss_validation_vector(context->constants.cameraFwd);
			capture["up"] = dlss_validation_vector(context->constants.cameraUp);
			capture["right"] = dlss_validation_vector(context->constants.cameraRight);
			capture["result"] = (int)result;
			print_line("[DLSS-VALIDATION] " + JSON::stringify(capture));
		}
'''

EVALUATE = r'''
		if (dlss_validation_capture) {
			Dictionary capture;
			capture["stage"] = "evaluate";
			capture["seq"] = dlss_validation_seq;
			capture["rr"] = use_dlss_rr;
			capture["result"] = (int)result;
			print_line("[DLSS-VALIDATION] " + JSON::stringify(capture));
		}
'''

FG = r'''
	if (dlss_validation_capture && p_params.dlss_g && StreamlineContext::get().slDLSSGGetState != nullptr) {
		sl::DLSSGState state;
		sl::Result state_result = StreamlineContext::get().slDLSSGGetState(context->viewport, state, nullptr);
		Dictionary capture;
		capture["stage"] = "fg_state";
		capture["seq"] = dlss_validation_seq;
		capture["result"] = (int)state_result;
		capture["status"] = (int)state.status;
		capture["presented"] = state.numFramesActuallyPresented;
		capture["min_dimension"] = state.minWidthOrHeight;
		capture["max_generated"] = state.numFramesToGenerateMax;
		print_line("[DLSS-VALIDATION] " + JSON::stringify(capture));
	}
'''

def prepare(variant, instrument=True):
    dlss = blob(REFS["pr18"] if variant in ("pr18", "both") else BASE, DLSS)
    forward = blob(REFS["pr17"] if variant in ("pr17", "both") else BASE, FORWARD)
    manifest = {"variant": variant, "base": BASE, "pr17": REFS["pr17"], "pr18": REFS["pr18"], "instrumented": instrument,
                "production_sha256": {DLSS: hashlib.sha256(dlss.encode()).hexdigest(), FORWARD: hashlib.sha256(forward.encode()).hexdigest()}}
    if instrument:
        dlss = replace_once(dlss, "using namespace RendererRD;", "using namespace RendererRD;\n\n#ifdef ENABLE_DLSS\n" + HELPER + "\n#endif")
        anchor = "void DLSSEffect::_upscale_internal(RDD::CommandBufferID cmdid, const DLSSContext::Parameters &p_params) {\n\tDLSSContextInner *context = (DLSSContextInner *)p_params.context;"
        dlss = replace_once(dlss, anchor, anchor + '\n\tstatic const bool dlss_validation_capture = OS::get_singleton()->has_environment("GODOT_DLSS_CAPTURE");\n\tstatic int64_t dlss_validation_counter = 0;\n\tconst int64_t dlss_validation_seq = ++dlss_validation_counter;')
        call = "\t\tsl::Result result = StreamlineContext::get().slSetConstants(context->constants, *StreamlineContext::get().last_token, context->viewport);"
        dlss = replace_once(dlss, call, call + CONSTANTS)
        for feature in ("sl::kFeatureDLSS_RR", "sl::kFeatureDLSS"):
            call = f"\t\t\tresult = StreamlineContext::get().slEvaluateFeature({feature}, *StreamlineContext::get().last_token, inputs, 1, nativeCmdlist);"
            dlss = replace_once(dlss, call, call + EVALUATE)
        dlss = replace_once(dlss, "\t// NIS support", FG + "\n\t// NIS support")
    for name, content in ((DLSS, dlss), (FORWARD, forward)):
        (SOURCE / name).write_text(content, encoding="utf-8", newline="\n")
    manifest["built_source_sha256"] = {name: hashlib.sha256((SOURCE / name).read_bytes()).hexdigest() for name in (DLSS, FORWARD)}
    artifact_stem = variant if instrument else variant + "-restored"
    (ROOT / "logs" / f"{artifact_stem}-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (ROOT / "logs" / f"{artifact_stem}-source.patch").write_bytes(subprocess.check_output(["git", "diff", "--", DLSS, FORWARD], cwd=SOURCE))
    print(json.dumps(manifest, indent=2))

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("variant", choices=["baseline", "pr17", "pr18", "both"])
    parser.add_argument("--no-instrument", action="store_true")
    args = parser.parse_args()
    prepare(args.variant, not args.no_instrument)
