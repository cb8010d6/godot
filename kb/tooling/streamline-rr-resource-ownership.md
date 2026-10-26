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
