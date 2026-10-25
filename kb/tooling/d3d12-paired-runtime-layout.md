---
type: Finding
title: Keep Agility Core and SDKLayers together outside the application root
description: Isolate factory and legacy debug lookup without replacing system DLLs.
tags: [windows, d3d12, agility, validation, packaging]
status: draft
generated: { by: codex, at: 2026-10-26T00:00:00Z }
---

Flat staging put Agility SDKLayers 1.618.5 next to a legacy application using
system Core 10.0.19041.7291. The first device call failed because the debug
layer ABI did not match. It reproduced without Streamline, so it does not
establish a beta1 or SL2.14 regression.

Eight controls with the pinned diagnostic binary a182f0c9f2 all create a real
D3D12 device (HRESULT S_OK): no-SL factory, forced no-SL legacy, SL2.10 legacy
and SL2.14 legacy, each with normal/debug startup. Put both Agility DLLs in
`x86_64/`, with no SDKLayers at application root. Factory selects its local
Core/layer pair; legacy selects the system Core and system layer
10.0.19041.5794. Different Windows patch versions alone are not an ABI mismatch.
The SL2.10 control still emits separate SDK diagnostics; these are not erased.

The editor packager had the same flat layout and now stages this pair in the
architecture directory. Existing export multiarch layout already does so.
Current production binary debug rendering and actual packaged standard/Mono
regressions remain required; diagnostic device creation is not full rendering
acceptance. No Windows system DLL, debug flag or production device path changes.
