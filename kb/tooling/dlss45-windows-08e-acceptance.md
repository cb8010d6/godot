---
type: Finding
title: Fixed 08e Windows GPU request and startup controls
description: Exact-head builds and requests pass, Vulkan feature-chain VUID disappears, legacy D3D12 layer mismatch is isolated, model proof remains missing.
tags: [windows, dlss, streamline, vulkan, d3d12, testing]
status: draft
generated: { by: codex, at: 2026-10-25T00:00:00Z }
---

At `08e97fb8a6871cfe39f83a24e2a5813936efd208`, six MSVC targets built,
both smoke variants and four installed-template games ran, and 30 actual
Vulkan/D3D12 SR request cases matched the K/M/L/default policy. The 85/18
typed CPU checks are separate from these GPU runs. Driver overrides remain
enabled; the active-model overlay is missing, so DLSS 4.5 is unconfirmed.

Vulkan 1.4.341 / layer 1.4.366 reported zero target pNext-02830 in all six
controls. NIS/FG/platform diagnostics remain. A separate diagnostic engine
proved no-SL forced legacy has the same debug failure as SL2.10/2.14:
system Core and application SDKLayers have mismatched SDK versions. The
matched Agility factory path succeeds. This is attribution, not a fixed
legacy integration or clean validation claim.

Both old/new engines reproduce the first-import singleton failure under the
shared cache; isolated cache retries removed the observed Mono safe-save
error. Do not call cache isolation a proven engine fix or disable protections.
See the [full public-safe record](../../devtools/WINDOWS_08E_ACCEPTANCE_2026_10_25.md).

On 2026-10-26 the saved pre-beta `25f6a147ed` engine reproduced the same
SL2.10 legacy failure only with `--gpu-validation`; ordinary D3D12 and the
no-SL factory debug control succeeded. Old/new Agility Core/layer hashes
match and the driver/installer code is unchanged by stage A. In the current
dependency environment the failure predates beta1. This is not historical
OS/driver reconstruction or pure-old-model proof: old logs include downloaded
plugins and the old SDK has no newer OTA opt-out.

The complete [report and evidence](../../devtools/acceptance/08e97fb8a6-20261025/REPORT.md)
now retain path-sanitized receipts/logs and unchanged application PNGs with
raw/public hashes. SDK/runtime binaries and private process/desktop data are
excluded. A missed observation by the user is not evidence of missing HUD
fields; actual model identity remains unconfirmed.
