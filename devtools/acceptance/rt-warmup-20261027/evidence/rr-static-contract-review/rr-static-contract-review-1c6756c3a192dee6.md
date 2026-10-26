# First-RR reset: contract and negative-control design

CPU/source review only. No source edit, native build or GPU run was performed here. The frozen d29 release evidence and earlier RR failures remain unchanged.

The original host-first-reset hypothesis is **weakened by the published SDK implementation**. In the versioned RR plugin, a missing feature handle or changed mode/output/normal layout/preset causes the common reset bit to be forced true. End-event uses the same common-constants pointer and forwards that bit to NGX. Therefore a false host input does not imply a false first-call NGX reset. A fresh-process, single-viewport F-preset failure is not explained by this omission alone under that implementation. These are published source facts; the shipping DLL's internals have not been instrumented. [RR plugin lines 305–358](https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/source/plugins/sl.dlss_d/dlss_dEntry.cpp#L305), [same pointer at 498](https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/source/plugins/sl.dlss_d/dlss_dEntry.cpp#L498), [NGX argument at 845](https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/source/plugins/sl.dlss_d/dlss_dEntry.cpp#L845).

The public constants contract associates reset with disconnected frame history/invalid motion vectors. It does not itself specify an explicit host-first-call rule. No separate first-call requirement was found in the checked versioned RR integration guide. [Constants contract](https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/include/sl_consts.h#L231), [RR guide](https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/docs/ProgrammingGuideDLSS_RR.md).

The host currently always supplies false from `render_forward_clustered.cpp` and copies it to common constants in `dlss.cpp`. Camera cuts, RR off/on reuse, and recycled viewport IDs still deserve a separate history/lifetime audit: the host recycles IDs while its destructor does not free RR/SR feature resources. An already existing same-size plugin handle may avoid first-create detection. That is distinct from the fresh one-viewport F reproduction and is not proven by it. Do not add unsynchronized feature destruction or reset every frame as a workaround.

## Smallest private leaf control

Keep one compiled binary for both runs, F requested in both, same frozen SDK214/probe/VVL, fresh profiles, FG plugin omitted, NIS0. A startup-only environment flag defaults false. Store the flag and a `rr_has_successful_evaluation=false` bit on each private DLSS context. Immediately before the existing constants setter:

```cpp
const bool diagnostic_first_reset = context->diagnostic_reset_first && use_dlss_rr && !context->rr_has_successful_evaluation;
context->constants.reset = (p_params.reset_accumulation || diagnostic_first_reset) ? sl::Boolean::eTrue : sl::Boolean::eFalse;
```

After the actual `slEvaluateFeature(kFeatureDLSS_RR, ...)` return, set the success bit only on `eOk`. Do not consume it when constants are set, a callback is merely queued, mode is Off, the pipeline is pending, or evaluation fails. Keep all existing error returns and model/preset selection. Log the requested flag, viewport, frame token, host effective reset and actual RR result. Label reset as the **host input**; it is not NGX-internal readback because Streamline copies and can modify constants internally.

This leaf deliberately tests only the first successful RR evaluation of a new host context. It is not a complete camera-cut, re-enable, resize, preset-change or lifetime fix. Default flag0 should leave existing constants, SR, RR, FG and Reflex behavior unchanged. Do not set first-RR state on a standalone SR evaluation.

Require both runs to establish actual F request, non-Off/eOk RR call, one complete eight-tag viewport, real RR SDK state/version, 49 captures, layer readback and no sampled RTSS/FG plugin. Strict errors always remain FAIL. If flag0 and flag1 both fail identically, retain the negative result and stop treating host-first-reset as the fresh-F root cause. If only flag1 is clean, repeat interleaved fresh runs and examine why the released DLL differs from published auto-reset behavior before proposing a production change. D is a separate requested-preset control, not proof of another model's identity or an equivalent-quality repair.
