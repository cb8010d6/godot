---
type: Finding
title: Give Streamline an R32F Vulkan depth input with explicit producer ordering
description: Candidate avoids native depth-to-color clone errors while preserving sampled depth precision and the D3D12 path.
tags: [streamline, vulkan, depth, synchronization, testing]
status: draft
generated: { by: codex, at: 2026-10-26T00:00:00Z }
---

The actual SL2.10/2.14 controls retain oldLayout-01213, copy-aspect-06663 and
pending clone layout 09600. They concern SDK depth cloning, separately from
the fixed NIS shader output and host device requirements. Full objects,
command regions and messages remain in the raw logs.

The candidate converts only Vulkan depth/stencil textures to a persistent
R32F color input before external evaluation. A shader sample preserves the
reversed, nonlinear depth, not a raw incompatible aspect copy or linearized
depth. Graph dependencies cover the producer and SDK reader. Existing R32F
PT depth and D3D12 inputs remain untouched. Cost is one dispatch and four
bytes per internal-resolution pixel. Actual GPU comparison, lifecycle and
performance are required before claiming resolution.
