---
type: Finding
title: Native evaluators need legacy resource preparation and binding invalidation
description: D3D12 debug rendering exposes callback state omissions after device creation succeeds.
tags: [d3d12, streamline, rendering-device, validation]
status: draft
generated: { by: codex, at: 2026-10-26T00:00:00Z }
---

With paired runtime lookup, current f9207b88db creates and renders a no-SL
D3D12 debug scene without errors. Actual SR, SR+NIS and FG scenes exit zero
but report 3993/4999/6593 early D3D12 diagnostics. First messages identify
velocity/color/UAV state mismatches (#527/#538) and SDK descriptor heaps left
bound for Godot descriptor tables (#708). Device creation is not acceptance.

Legacy D3D12 ignores graph barriers, relying on uniform-set preparation for
native draw/compute commands. An external callback has no such shader binding,
so its graph-declared textures never enter the states advertised to Streamline.
The SDK also replaces command-list bindings while the backend cache still
considers Godot's heaps/pipeline/signatures current.

Record texture IDs/layouts on the callback command. A driver preparation hook
establishes the declared legacy states through existing subresource tracking,
flushes transitions and invalidates cached bindings. Vulkan retains its graph
barriers; no Vulkan/D3D12 layout assumption is shared. Enhanced D3D12 retains
its existing graph barrier path; Windows 11 enhanced/native interop is not
validated by the Windows 10 legacy test. Current fix awaits build/GPU regression.

Reproduce with a paired runtime directory and the existing DLSS 4.5 scene under
`--gpu-validation --rendering-driver d3d12`, sharpness zero/nonzero and FG on/off.
Capture OutputDebugString from process creation, not just engine stdout.

The first e627be688e standard build failed: VectorView has no range-for
begin/end. Replace that traversal with indexed access; the failed compiler
receipt is retained. No GPU result is attributed to that unbuilt revision.
