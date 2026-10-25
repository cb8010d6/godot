---
type: Finding
title: Separate the D3D12 legacy runtime path from Streamline interposition
description: Diagnostic-only startup tracing and a no-Streamline legacy control for the fixed Windows candidate.
tags: [windows, d3d12, streamline, debugging, validation]
status: draft
generated: { by: codex, at: 2026-10-25T00:00:00Z }
---

Base candidate: `08e97fb8a6871cfe39f83a24e2a5813936efd208`.
Its six real MSVC targets built, both smoke variants ran, four installed-template
games exported/ran, and 30 SR request/render cases passed. Active model evidence
remains distinct from SDK request success. Vulkan 1.4 controls removed the
aggregate/promoted-feature VUID but retained other NIS/FG/platform diagnostics.

The prior no-SL versus SL debug-layer comparison changed two variables: a
no-SL device normally uses an Agility factory, whereas SL selects legacy
creation. This local diagnostic branch traces the actual paths and adds
`GODOT_ACCEPTANCE_FORCE_D3D12_LEGACY=1` for the missing no-SL control.

The diagnostic guard runs after loading d3d12/dxgi/dcomp libraries, preserves
those handles and returns `OK` before factory creation. Returning at the
function entry would also skip required library initialization and would
produce an invalid control. The function returns `Error`, not `bool`.

Capture the factory presence, adapter LUID, feature level, requested IID,
first HRESULT, pointer-owner DLLs and actually loaded runtime/layer modules.
A launcher debugs only its own child, captures early OutputDebugString and
contains all descendants in a kill-on-close Job. Compare normal/validation
startup for no-SL factory, no-SL legacy, SL2.10 and SL2.14.

This instrumentation is diagnostic-only, not a proposed fix. Do not merge
the environment switch into a release or claim that forwarding one function
pointer fixes interoperability. Matrix results will be recorded separately.
