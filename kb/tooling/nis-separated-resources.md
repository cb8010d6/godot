---
type: Finding
title: Separate NIS shader format and resource lifetime from DLSS output
description: Candidate RGBA32F NIS output and explicit render-graph dependencies, with strict GPU validation pending.
tags: [streamline, nis, vulkan, synchronization, testing]
status: draft
generated: { by: codex, at: 2026-10-26T00:00:00Z }
sources:
  - id: nis214
    url: https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/docs/ProgrammingGuideNIS.md
  - id: nis-plugin214
    url: https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/source/plugins/sl.nis/nisEntry.cpp
---

The fixed 08e baseline and current integration's identical native tree tag
the same RGBA16F output for NIS input/output. Real sync validation reports
WAW around volatile-clone barriers; the shader's Rgba32f output also reports
undefined storage values. These are distinct from the no-SL surface failure
and other SL depth/device/present diagnostics.

The candidate gives DLSS a persistent RGBA16F intermediate and NIS a distinct
RGBA32F output, schedules separate graph callbacks, then converts to the
original renderer format. Stable NIS tags avoid a volatile clone and resource
aliasing. The plugin's free hook clears its cached native-resource descriptions
when those resources are destroyed.[^nis214][^nis-plugin214]

Memory is 24 bytes/output pixel while sharpening is used; conversion adds
one dispatch. Actual GPU strict-validation, image, timing and lifecycle tests
are required before calling this fixed. See the [stabilization record](../../devtools/STABILIZATION_4_8_BETA1_SL214.md).

The first local editor build passed but reported three new deprecated `free`
calls; the candidate uses the current `free_rid` API instead. Keep that build
receipt separate from the rebuilt final candidate. Verbose first-evaluation
output records the actual resource formats, alias check and SDK result.

At `94c27203b1` the rebuilt standard editor and nine short real GPU cases
completed. Nonzero-sharpness evaluations logged actual RGBA16F/RGBA32F,
non-aliased resources and eOk; NIS format and sync messages disappeared.
The other Vulkan VUIDs remain, and lifecycle/performance is still pending.
The copied fixture's optional native probe did not load, so no FG activation
or runtime-module proof is claimed from its missing state file.
