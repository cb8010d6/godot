---
type: Finding
title: Map RR validation images to actual host resource tags
description: A strictly isolated RR game still fails after omitting the FG plugin; correlate native image handles before changing synchronization.
tags: [streamline, vulkan, ray-reconstruction, synchronization, testing]
status: draft
generated: { by: codex, at: 2026-10-26T18:31:00Z }
---

# Reproduced boundary

Candidate `8a7364bf6c52022eab78ed33298e7539449e8c88` completes the real
game's two startup gates and reaches PLAY on RTX 4060 Laptop GPU. A separate
strict wrapper proves the actual owned process, VVL 1.4.366, synchronization
validation, no sampled RTSS module, and no loaded DLSS-G DLL in 36 samples.
The strict result remains **FAIL**: four WAW diagnostic text tokens and eight
09600 tokens. Functional completion and exit 0 do not override that failure.

The messages describe a clear after a layout transition and GENERAL versus
UNDEFINED state for images named `nv.ngx.dlssd.resource` inside RR evaluation.
Names alone do not establish ownership. No host allocation/release callbacks
are supplied; ordinary host input/output textures are nevertheless tagged.

# Private instrumentation, not a repair

Temporarily enable `GODOT_STREAMLINE_TRACE_RR_RESOURCES=1` before starting the
test process. `SL_RR_TAG` records each actual viewport/tag/RID/native-image
combination from the exact assignResource path. Its state is the host's
declared state, not a readback of the validation layer's tracked state.
The requested RR bit also does not establish a successful SDK evaluation.

This diagnostic changes no allocation, resource state, graph dependency or
feature selection. The per-thread set is appropriate only for a bounded
private experiment and must be removed before final delivery. Compilation,
GPU mapping and a verified RR correction are pending at preparation.

The subsequent c326 diagnostic build/run mapped all 16 host tags in two RR
contexts; none matched the eight error images. This rejects the direct
host-tag-identity explanation for these particular images, not all host-induced
SDK faults. The repeated SDK214 run retained four WAW and eight 09600 tokens.

A same-binary complete-SDK210 comparison first reported strict CLEAN, but its
repeat lost the device before any RR tags appeared. Subsequent command-pool
VUIDs followed the fence error -4. Preserve both runs; old SDK stability and a
safe downgrade are not established. The first clean run's tags demonstrate RR
options/resources, but the outer non-Off mode guard leaves an evaluation-proof
gap. A temporary once-per-context `SL_RR_EVALUATE` marker after the actual RR SDK
call now records mode/result to close that gap. This second probe remains
unbuilt/unrun at preparation; it is not model or output-quality evidence.

Hypotheses: incorrect host tag/dependency; stale state after context/resource
reuse; or SDK-private first-evaluation initialization. A matched native image
can localize a host problem. Unmatched images are inconclusive until all real
tags and lifetimes have been captured. A broad external barrier cannot repair
incorrect ordering between two operations inside a closed SDK evaluation.

# Measured outcome and cleanup

Native diagnostic `8b1055662793954959fe5ce8b11843437af0adc3` directly records
the actual RR call returning eOk (0), non-Off mode 3, for both viewports in each
complete SDK214/SDK210 comparison. The same executable with the complete
SDK214 distribution retains four WAW and four original 09600 messages (eight
09600 text tokens). SDK210 is CLEAN in this bounded follow-up; its earlier
pre-evaluation device loss is still a failure and prevents a stability or
production-downgrade recommendation. The sampled modules match each frozen
distribution, not cached cross-version replacements. `sl.dlss_g.dll` is absent;
NGX's `nvngx_dlssg.dll` may nevertheless be mapped and is not claimed absent.

The problem also reproduces in the existing public GPU fixture's single-view
`--mode=rr` motion case with SDK214, FG plugin omitted and NIS off. All 49 real
frame records/captures and 160 SDK samples complete, the actual RR evaluation
returns eOk and eight real RR tags are recorded. Strict validation still fails:
two WAW and two original 09600 messages. It needs no private game content.
The one-view fixture is a narrower reproducer, not a repaired result.

The temporary host-tag and evaluation instrumentation is removed after this
measurement; the frozen binaries, source commits and original logs retain it.
Normal renderer behavior is not changed to suppress SDK diagnostics. The
startup-only FG opt-out is separately measured for SR; it does not cure RR.
The evidence points to the new runtime combination's first RR initialization
path, with no error image matching supplied host tags. Exact closed NGX
allocation/transition implementation remains unverified. A vendor runtime fix
or a separately verified host-contract correction is still required before
calling SDK214 Vulkan RR strict-clean. No unrelated post-device-loss recovery
refactor is mixed into this upgrade.
