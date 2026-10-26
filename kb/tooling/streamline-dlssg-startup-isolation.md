---
type: Finding
title: Isolate DLSS-G plugin startup from SR and RR validation
description: A real RTSS-isolated SDK 2.14 SR baseline still reports pacer layout errors; a startup-only diagnostic control is prepared without changing normal FG or Reflex behavior.
tags: [streamline, vulkan, synchronization, frame-generation, testing]
status: draft
generated: { by: codex, at: 2026-10-26T17:06:08Z }
sources:
  - id: sdk-features
    url: https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/docs/ProgrammingGuide.md#2221-managing-features
    title: Streamline startup feature selection
  - id: sdk-pacer
    url: https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/docs/ProgrammingGuideDLSS_G.md#180-how-to-avoid-unnecessary-overhead-when-dlss-g-is-turned-off
    title: Loaded DLSS-G plugin asynchronous presentation while FG is off
  - id: sdk-api
    url: https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/source/core/sl.api/sl.cpp#L1080
    title: Feature context validation before a function query
  - id: isolated-baseline
    resource: "<private-evidence>/sdk214-sr-rtss-isolated-20261026T164512Z-eb66acab/result.json"
    title: Original Windows RTX isolated SR baseline and raw receipt identities
---

# Measured baseline, still a strict failure

A frozen `a73826e8c0fd90351a1bae5095ce87bc6210be7f` editor with SDK
2.14.16 runs the original visible Vulkan Quality / Recommended / NIS-off
motion fixture on RTX 4060 Laptop GPU. Native exit is 0, all 49 frame records
and captures complete, and infrastructure/isolation readbacks pass. The current
VVL manifest actually reports 1.4.366, despite its older directory name.

The loader inserts only `VK_LAYER_KHRONOS_validation`; owned-process module
samples contain no RTSS module. `NvSPcap64.dll` is still observed and is not
claimed removed. A separately measured no-SL clean control also retains that
module, but this correlation does not prove that every overlay interaction is
harmless. The fresh SDK baseline still has **10 original 09600 messages**
(20 text tokens because VUIDs repeat in message text/links), and 10 engine error
lines. `03868` is **not observed in this bounded run**; its old failure remains
preserved and is not declared repaired. Synchronization validation remains FAIL.

The actual message names the DLSS-G pacer's CopyImage and fake swapchain image:
expected TRANSFER_SRC, tracked PRESENT. The Draw-shaped VUID is not evidence
that an ordinary material descriptor caused it. Object ownership localizes the
operation; it does not establish sole SDK or host fault.

Evidence label: `sdk214-sr-rtss-isolated-20261026T164512Z-eb66acab`.

| Raw artifact | SHA-256 |
|---|---|
| `result.json` | `cedb5a74195f9349d360470410d82c9d401a4930488259eb8a37ce885ada1f32` |
| `receipt.json` | `a1598f6449d2c49a9e3d0457a4c251d65d5f6aeb6593d76f1e1f678ea3a7f499` |
| `module-samples.json` | `2f27614e0696aceb4a0eebe4ce2eae7c66af8fa0faa36313ab9678af998989a2` |
| `godot.stdout-and-stderr.log` | `073e304b1479f33862077cddc1ed6d8c6edfbab4c9d4010b846dbb19f05f96e1` |

# Startup-only diagnostic candidate

Games currently request DLSS_G during `slInit` even with window FG Off.
The SDK describes a loaded FG plugin's asynchronous queue/offscreen copy;
runtime interpolation Off is not equivalent to omitting that plugin.[^sdk-pacer]

`GODOT_STREAMLINE_DISABLE_DLSS_G=1` is a diagnostic process-startup switch,
latched before SDK/device/swapchain initialization. It omits only DLSS_G from
the feature list, skips both FG function queries, and makes FG capability false.
SR, RR, NIS, PCL and Reflex selection and their error paths remain unchanged.
Unset or any value except exact `1` retains normal behavior. There is no runtime
plugin unload/reload, new script property, changed enum, or claimed FG feature.
The SDK's requested feature list is the supported startup selection seam.[^sdk-features]

Existing FG renderer/policy/status guards see a null options function and false
capability, and therefore report unavailable. Terminal shutdown and present
semaphore code are unchanged. This candidate is **not a synchronization fix**;
candidate build and same-binary A/B GPU controls are pending at preparation.

The old acceptance probe directly queries FG version/getter even in an SR test.
SDK source reports missing-feature errors for such queries, rather than loading
the omitted plugin.[^sdk-api] Both new A/B cases must use the same independently
identified guarded probe: when the actual FG DLL is absent, record an explicit
skip without a fabricated SDK return. Preserve real SR/RR/Reflex queries and
PCL version/capability observations. Keep all raw logs and old probe inputs.

Require actual VVL/sync readback, no RTSS modules, FG capability/status
unavailable and no sampled `sl.dlss_g.dll` in the disabled case. Compare a single
new candidate binary with switch absent versus `1`; A738 versus a new disabled
candidate alone changes more than one input. A clean disabled result would
implicate the loaded-FG presentation path, not establish a production repair or
validate ordinary FG, MFG, RR, model identity, latency or long-term reliability.

[^sdk-features]: Pinned Streamline feature initialization contract.
[^sdk-pacer]: Pinned DLSS-G initialization and asynchronous presentation guide.
[^sdk-api]: Pinned SDK feature context and function lookup implementation.

## Measured follow-up

All six Windows native targets at `8a7364bf6c52022eab78ed33298e7539449e8c88`
build with Jobs 2 in 3923.813 seconds. The same-binary isolated SR A/B pair
retains the loaded-FG pacer 09600 failure in the default case and is strictly
CLEAN when the exact startup opt-out is 1. The guarded probe records actual
FG capability/status unavailable and no sampled `sl.dlss_g.dll` in that case;
SR/RR/NIS/PCL/Reflex capabilities remain available. This does not assert that
every NGX FG-related DLL is unmapped. No new FG/model/latency pass follows.

Actual game RR still fails independently with FG omitted; see
[RR resource ownership](streamline-rr-resource-ownership.md). Its single-view
public reproducer also fails. The switch is a scoped SR workaround/diagnostic,
not a complete Vulkan Streamline synchronization repair or a reason to ignore
the original validation messages. Default startup selection is unchanged.
