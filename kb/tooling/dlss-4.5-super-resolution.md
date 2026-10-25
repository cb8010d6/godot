---
type: Finding
title: Request DLSS 4.5 SR presets and verify the active model separately
description: An opt-in K/M/L mode policy preserves runtime defaults while keeping requested presets distinct from GPU model evidence.
tags: [dlss, streamline, presets, testing]
status: draft
generated: { by: codex, at: 2026-10-25T00:00:00Z }
sources:
  - id: sdk
    url: https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/docs/ProgrammingGuideDLSS.md
    title: Pinned Streamline DLSS programming guide
  - id: nvidia
    url: https://www.nvidia.com/en-us/geforce/news/dlss-4-5-super-resolution-available-now/
    title: NVIDIA DLSS 4.5 Super Resolution guidance
---

# Request policy

The existing `dlss_preset` setting gains an opt-in `Recommended` value:
K for DLAA/Quality/Balanced, M for Performance and L for Ultra Performance.
This is the pinned SDK's recommended policy, not a claim that every mode
uses the new model. Explicit M/L request the second-generation Transformer
in other modes too. Keep `?` as the default and preserve fixed presets.[^sdk]

The production helper applies presets immediately before the typed
`slDLSSSetOptions` callback. A standalone capture test checks the submitted
slots, mode/size/exposure preservation, switching, error forwarding and
invalid-input rejection. Actual Windows-target client compilation checks
the enabled code. These do not execute a GPU model.

# Verify the model

RTX40 can run the new SR models. Driver overrides can change the application's
request, and the public DLSS state does not expose resolved model generation.
Record NVIDIA's DLSS statistics overlay and runtime provenance separately;
if that evidence is unavailable, retain "active model unconfirmed".[^nvidia]

RR uses its own preset enum and replaces SR evaluation. Dynamic MFG and
RTX50 testing are excluded. The concrete build, GPU and debug-layer work
order is [the Windows handoff](../../devtools/DLSS_4_5_WINDOWS_HANDOFF.md).

[^sdk]: Section 5 and the public DLSS options in v2.14.16.
[^nvidia]: NVIDIA's documented model and overlay guidance.
