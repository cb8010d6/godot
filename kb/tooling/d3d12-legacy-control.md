---
type: Finding
title: Separate the D3D12 legacy runtime path from Streamline interposition
description: Diagnostic-only startup tracing and a no-Streamline legacy control for the fixed Windows candidate.
tags: [windows, d3d12, streamline, debugging, validation]
status: stable
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

The first instrumentation build used `GetDesc1` on the device driver's
`IDXGIAdapter` and failed to compile. Correct the trace to `GetDesc` and
`DXGI_ADAPTER_DESC`; both expose the same LUID. Keep this failed diagnostic
receipt separate from the successful exact-candidate six-target build.

## Measured startup comparison

Diagnostic engine `a182f0c9f24411242f18b68aa5d91ece9acb983e` was built
after correcting that trace. On Windows 10 19045 / RTX 4060 Laptop / 610.88:

| Device path | Ordinary startup | Debug-layer startup |
| --- | --- | --- |
| No SL, Agility factory | D3D12, S_OK | D3D12, S_OK |
| No SL, forced legacy | D3D12, S_OK | E_INVALIDARG, Vulkan fallback |
| SL 2.10, legacy | D3D12, S_OK | E_INVALIDARG, Vulkan fallback |
| SL 2.14, legacy | D3D12, S_OK | E_INVALIDARG, Vulkan fallback |

All rows used the same adapter LUID, requested feature level 11_0 and
IID_ID3D12Device. The reported D3D12 API capability was 12_0. Exit zero
after Vulkan fallback does not count as a D3D12 validation pass.

Early OutputDebugString in all three failing rows explicitly reported
`SDKLayers dll does not match the D3D12SDKVersion of D3D12 Core dll`.
Legacy debug startup selected system Core 10.0.19041.7291 and the application's
Agility SDKLayers 1.618.5.0.20251205.1. The factory path selected the local
Core/SDKLayers pair at 1.618.5.0.20251205.1. Function-owner and load-event
records distinguish selection at device creation from modules loaded later.

This reproduces the failure without Streamline and identifies a legacy
runtime/layer version-selection problem. It is not evidence of a new 2.14
interposer regression. No DLL was removed/replaced to manufacture a pass,
and no production compatibility fix is claimed. A future fix must select a
coherent runtime/layer pair and rerun this matrix, rather than only forwarding
one debug-interface pointer.
