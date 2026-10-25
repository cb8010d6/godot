---
type: Finding
title: DLSS output must be declared as written in the render graph
description: A Windows RTX moving-marker reproduction isolates an inherited one-frame DLSS output ordering defect.
tags: [streamline, dlss, render-graph, regression]
status: draft
generated: { by: codex, at: 2026-10-25T00:00:00Z }
sources:
  - id: existing-report
    url: https://github.com/NVIDIA-RTX/godot/pull/14
    title: Existing report of DLSS output synchronization
---

# Reproduction and isolation

The pinned upgrade still declares the DLSS output as a sampled texture.
The current Diginaat `dev` implementation was checked and retains that
declaration. The independent local reproduction moves an unshaded red
marker by a fixed distance per rendered sample and compares real viewport
captures with a native-rendering control. It measures image phase, not
physical input latency.

On Windows 10 / RTX 4060 Laptop / driver 610.88, 960x540 Vulkan, SDK
2.14.16 and NGX 310.9.16, the median displacement after eight initial motion
samples was -5.927 pixels against a 6-pixel native step (0.988 extra frames).
Disabling render-graph reordering reduced it to -0.004 frames; full barriers
alone retained 0.988 frames; FSR2 measured -0.003 frames. All 48 motion
captures per run are retained. The first eight are excluded only from the
settled statistic. These controls support a missing ordering dependency.

# Local correction under test

Declare the output as a storage-image write dependency and tag it in the
matching Vulkan GENERAL or D3D12 UNORDERED_ACCESS state. Input tags retain
their existing shader-read state. This is an independent local regression
branch; no third-party PR commit was copied and the correction is not part
of either upgrade review branch. Rebuild and GPU regression are pending.
