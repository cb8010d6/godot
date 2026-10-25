---
type: Mistake
title: A legacy D3D12 control must retain loader initialization
description: Skip only device-factory creation when comparing Agility and legacy paths.
tags: [testing, d3d12, debugging]
status: stable
generated: { by: codex, at: 2026-10-25T00:00:00Z }
---

# What happened

The Windows handoff incorrectly suggested returning `false` at the entry of
`_init_device_factory()`. The actual function returns `Error` and first loads
D3D12, DXGI and optional DComp. A valid control must preserve those loads.

# Rule

On a diagnostic branch, return `OK` after the loader initialization and before
the factory-selection code. Check module handles, factory absence and the
first failure location. A loader/setup failure is not evidence of failure in
legacy `D3D12CreateDevice`. The correction changes documentation only; it
does not establish a root cause for the separately reported startup failure.
