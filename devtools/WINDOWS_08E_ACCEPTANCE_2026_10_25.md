# Fixed 08e candidate: Windows / RTX acceptance

Tested production source: `08e97fb8a6871cfe39f83a24e2a5813936efd208`.
This is a measured follow-up to `DLSS_4_5_WINDOWS_HANDOFF.md`, not release
approval. Active DLSS 4.5 model identity remains unconfirmed.

The [full report and evidence archive](acceptance/08e97fb8a6-20261025/REPORT.md)
contains command receipts, sanitized complete logs, original application PNGs,
fixture sources and raw/public SHA-256 provenance. The 2026-10-26 supplement
adds the actual pre-beta controls below. No SDK/runtime or engine binaries
are included in the archive.

## Host and build

Windows 10 Pro 19045; RTX 4060 Laptop 8 GB, driver 610.88; Ryzen 9 7940H,
32 GiB. VS 2022 Community 17.14.42, MSVC 19.44.35229.0, Windows SDK
10.0.26100.0; Python 3.12.10/SCons 4.11.1; .NET SDK 10.0.402/runtime
10.0.13, net10.0. Real pinned PhysX 5.10.0/CUDA 12.8, Blast and Flow
dependencies were reused. No stub SDKs were substituted.

```powershell
devtools\build\build.ps1 -Target release -KeepGoing -Jobs 4 -VersionStatus beta1
devtools\test\smoke.ps1
devtools\test\smoke.ps1 -Mono
```

All six real Windows targets and managed assemblies built in **532.375 s**.
Both four-case smoke variants passed. All four production PCK checks passed,
83 standard/84 Mono assertions each. Public standard/Mono editor ZIPs and
template TPZs passed runtime exclusion checks. Installed-template lookup,
standard embedded PCK export, and self-contained C# export/run passed for
Debug and Release. Exported games used real D3D12/RTX; C# games ran without
SDK discovery and passed typed/dictionary PhysX queries. No package was released.

Initial failures were retained. First headless import under the shared cache
reported an EditorNode singleton error, reproducible with both the previous
138 engine and 08e; warm 08e imports were clean. The first Mono export exited
zero but logged a safe-save error. With an isolated editor cache, both Mono
exports/runs were clean. This is not a claimed engine cache fix; antivirus
and safe-save protections were not disabled. Full Windows native unit and
source-generator suites were not rerun for this head.

## SR policy and model evidence

MSVC `/W4 /WX` compiled and ran **85 checks / 18 typed callback submissions**
plus the API smoke. These are CPU boundary checks, not GPU/model validation.

There were **30 successful actual GPU request/run cases**, split equally
between Vulkan and D3D12: Recommended in DLAA/Quality/Balanced/Performance/
UltraPerformance; forced K/M/L; the unchanged `?` default; landscape,
ultrawide and portrait windows. Actual typed SDK submissions and eOk results
were recorded: Recommended K=11 for DLAA/Q/B, M=13 for Performance, L=12
for UltraPerformance. No backend fallback was accepted for these cases.

Separate Recommended/Performance runs completed 7200 scene updates on each
backend. Representative runtime queries reported SL 2.14.16 and NGX 310.9.16.
Read-only NVAPI still found global SR/RR/FG overrides enabled; raw SR/RR
preset values were 0x00FFFFFF, FG 0x00FFFFFE and MFG count zero. No driver
configuration was saved by the Agent.

**No active-model overlay proof was obtained.** Application requests, runtime
versions, model-set IDs and rendered images do not establish the resolved
model. NVIDIA App's statistics setup screen is not activity evidence. Keep
DLSS 4.5 SR marked unconfirmed until Vulkan and D3D12 running-model/preset
evidence is retained. See the official NVIDIA FAQ linked in the handoff.
The user clarified that they had simply not watched the earlier overlay;
this does not establish that model fields were absent or broken.

## Vulkan 1.4 controls

Actual GPU API was **1.4.341**; Khronos validation layer **1.4.366** was
confirmed in every log. The target promoted-feature conflict
`VUID-VkDeviceCreateInfo-pNext-02830` was absent in all six controls:

| Control | Target VUID | SYNC diagnostics |
| --- | ---: | ---: |
| No SL | 0 | 0 |
| SL2.14 NIS off / FG off | 0 | 0 |
| SL2.14 NIS on / FG off | 0 | 10 |
| SL2.14 NIS off / FG on | 0 | 20 |
| SL2.14 NIS on / FG on | 0 | 20 |
| SL2.10 NIS off / FG off | 0 | 0 |

The feature-chain correction works for these Vulkan 1.4 cases. The full
validation runs are still not clean: NIS/FG internal sync/format/swapchain
diagnostics and the inherited Win32 surface hinstance diagnostic remain.
Older-than-1.2 runtime behavior was not tested.

## Existing graphics corrections

Both backends retained the output-phase correction: 48 real marker captures
per run, first eight retained but excluded from the settled statistic, gave
about -0.004105 frames against the same-scene native control. The earlier
defect was about 0.988 extra frames. This is image phase, not physical latency.

D3D12 FG game-mode scene changes recorded 591/589/589 foreground presented-two
eOk samples across three scenes, 613 samples each. Vulkan FG controls also
ran. Reflex reports/timestamps remained available. Complex Vulkan PT/RR,
multiview/guides and ordinary exits ran with 29 original images and no engine
errors in normal execution. Generated intermediate-frame video and physical
latency acceptance remain unperformed. No old PR camera-case counts were
transferred to this head; the reviewed camera code was compiled and used
by the current rendered scenes.

## D3D12 debug-layer attribution

This experiment used a separate diagnostic derivative
`a182f0c9f24411242f18b68aa5d91ece9acb983e`, with early OutputDebugString,
pointer-owner/module and device-parameter tracing. It did not alter the fixed
candidate. The legacy guard preserved required DLL initialization and only
skipped factory creation. All cases used the same adapter, requested feature
level 11_0 and IID_ID3D12Device; supported D3D12 capability was 12_0.

| Path | Normal | Debug layer |
| --- | --- | --- |
| No SL / Agility factory | D3D12 S_OK | D3D12 S_OK |
| No SL / forced legacy | D3D12 S_OK | 0x80070057, Vulkan fallback |
| SL2.10 / legacy | D3D12 S_OK | 0x80070057, Vulkan fallback |
| SL2.14 / legacy | D3D12 S_OK | 0x80070057, Vulkan fallback |

All three failing rows explicitly reported SDKLayers/Core SDKVersion mismatch.
Legacy debug startup used system Core 10.0.19041.7291 with application
SDKLayers 1.618.5.0.20251205.1. Factory startup used the matched local Core/
SDKLayers pair 1.618.5.0.20251205.1. Module loads later in initialization
were kept separate from the create-device trace. The failure reproduces
without SL and is not a new 2.14-specific interposition regression.

This is a root-cause control, **not a production compatibility fix**. No Agility
DLL was deleted or replaced to manufacture success. Selecting a coherent
legacy runtime/layer pair needs its own change and regression. Diagnostic
instrumentation remains on the separate `diagnostic/d3d12-legacy-08e97fb8a6`
branch and is not part of release code.

### Pre-beta comparison, 2026-10-26

The saved real engine `25f6a147ed8ca36d521638ba2b5fe1715a3cbdaa` was run
with the same Agility Core/SDKLayers hashes. Its D3D12 driver code and the
Agility installer are unchanged by the stage-A beta1 merge. SL2.10 ordinary
startup used D3D12; adding `--gpu-validation` reproduced 0x80070057 and the
Core/SDKLayers mismatch, followed by Vulkan fallback. The old no-SL factory
control with validation succeeded in D3D12. This failure therefore exists
before beta1 in the current dependency environment; it is not a regression
newly introduced by that merge in these controls.

This reuses saved binaries rather than rebuilding a historical machine state.
The old SDK cannot honor the new OTA opt-out and its logs include downloaded
plugin loads. Do not use the old startup control as pure-old-model evidence.
The [three receipts and debug output](acceptance/08e97fb8a6-20261025/prebeta-comparison.json)
remain separate from the fixed candidate's SR results.

## Remaining acceptance

Draft review can continue with these limits disclosed. Do not claim full
DLSS 4.5 model, strict Vulkan/D3D12 validation, generated-frame visual,
physical latency, RTX50/6X/Dynamic MFG or long-run stability acceptance.
The Agent used real builds, SDK calls, GPU runs and captured artifacts;
no generated images or fabricated performance/pass records were used.
