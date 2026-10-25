# DLSS 4.5 Super Resolution and Windows validation work order

This continues the pinned Godot 4.8 beta 1 / Streamline 2.14.16 integration.
The scope now includes DLSS 4.5 Super Resolution on the available RTX 4060.
Dynamic MFG, RTX50 testing and new frame-generation controls are excluded.
Ordinary FG 2X and Reflex remain regression checks.

## What the code adds

The existing `rendering/streamline/dlss_preset` string setting gains
`Recommended`. The default remains `?`, and existing explicit letters remain
available. The same values work through
`Streamline.set_parameter(Streamline.STREAMLINE_PARAM_DLSS_PRESET, value)`.

| Selection | DLAA / Quality / Balanced | Performance | Ultra Performance |
| --- | --- | --- | --- |
| `?` | Runtime default | Runtime default | Runtime default |
| `Recommended` | K | M | L |
| `M` | M | M | M |
| `L` | L | L | L |
| `K` | K | K | K |

This follows the pinned [SDK DLSS guide, section 5](https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/docs/ProgrammingGuideDLSS.md#50-provide-dlss-options).
L and M request the DLSS 4.5 second-generation Transformer; K requests the
earlier Transformer. Recommended therefore uses L/M in the lower input
resolution modes. Explicit M/L also work in Quality, Balanced and DLAA.
NVIDIA documents support on RTX40 and the performance tradeoffs in its
[DLSS 4.5 SR announcement](https://www.nvidia.com/en-us/geforce/news/dlss-4-5-super-resolution-available-now/).
Do not require an RTX50 card for this SR work.

This policy applies to SR. RR replaces SR evaluation and keeps its independent
preset setting; SR's L/M must not be copied into the RR enum. FG and Reflex
settings are unchanged.

`--verbose` emits `DLSS SR requested options:` on mode or selection changes.
The record comes from the actual typed `slDLSSSetOptions` submission and
includes its result. It establishes the request, not the active model.
Driver overrides can change the resolved model. SDK/NGX version, model-set
number, a successful return, and an application-requested letter alone are
insufficient proof of active DLSS 4.5.

## Division of work

Cloud work supplies the preset implementation, typed SDK-boundary tests,
actual Windows-target object compilation, a repeatable scene, a separate
Vulkan feature-chain correction, and the source analysis below. It cannot
execute Windows/MSVC or an RTX GPU in this environment.

Windows work supplies exact-head builds, actual SDK calls and model evidence,
rendered comparisons, strict Vulkan diagnostics and the D3D12 startup matrix.
Each finding must identify its source commit, binaries and installed runtimes.

## 1. Pin the candidate before building

The assembled candidate starts from native-code commit `5bc3884986`, with
the previously reviewed camera corrections applied in the integration
follow-up. Its source composition is:

| Original correction | Applied integration commit |
| --- | --- |
| DLSS 4.5 SR policy and fixture | `1c9c9864b7` |
| DLSS output write/state (`3e024c0a01`) | `2775e4384f` |
| Abandoned RT pipeline ownership (`1050415573`) | `5507e26d7d` |
| PT/RR storage formats (`fcca7536eb`) | `dc2ae21ba3` |
| Clears and NIS tags (`e0c27964e8`) | `0b7a7f7758` |
| External callback stage scope (`1381c32593`) | `147b47cae5` |
| Vulkan promoted-feature chain (`b659925e67`) | `5bc3884986` |
| Vertical FOV (`2ccecd2d10`) | Camera-input follow-up |
| World-space camera axes (`0b50d914de`) | Camera-input follow-up |

Compared with the measured regression branch, the graph, PT ownership,
PT/RR formats, render-buffer allocations, build-isolation code and PhysX
module are unchanged. Native source differences are limited to the new SR
policy/logging, camera inputs and Vulkan feature-chain correction. Knowledge-base insertion
conflicts retained both sets of findings. Documentation commits may follow;
use the final received branch SHA for Windows build/test receipts.

Preserve the original upgrade and review branches. The measured native
engine was `1381c32593`, while the received SDK review head was `b88493491e`.
They differ in graphics code; the old six-build/GPU results do not validate
the new review head.

Use `integration/dlss45-windows-validation` from the personal fork for the
combined candidate. It includes the DLSS policy, the five independently
tested graphics corrections, and the Vulkan feature-chain candidate.
The feature and Vulkan corrections remain available on separate branches
for independent review. Resolve the exact integration SHA at intake, create
an isolated worktree, and keep that SHA fixed through the run. Record:

```powershell
git rev-parse HEAD
git status --porcelain
git remote -v
```

Keep local SDK paths in untracked `custom.py`. Check actual remote URLs;
only the personal fork may receive pushes. Do not create upstream issues or
PRs, merge into published branches, tag, or release during this work order.

## 2. Build and export on that exact source

Use the existing real PhysX/CUDA, Blast, Flow, D3D12 and .NET dependencies.
The module-version object/archive isolation fix is already in the review
base. Keep it, and avoid sharing generated/build outputs between worktrees.

```powershell
devtools\build\build.ps1 -Target release -KeepGoing -Jobs 4 -VersionStatus beta1
devtools\test\smoke.ps1
devtools\test\smoke.ps1 -Mono
devtools\package\package_templates_win64.ps1
devtools\package\package_templates_win64.ps1 -Mono
```

Require both editors and all four templates to build. Install the TPZs and
export/run standard and C# Debug/Release games through installed-template
lookup. Include standard embedded PCK and self-contained C# startup without
SDK discovery. Record binary versions and SHA-256 hashes, not only exit codes.

## 3. Run the SR/model matrix on RTX 4060

`devtools/test/dlss45_project` is an ordinary rendered game with moving camera
and geometry. Use the native-test wrapper so test-owned updater children are
contained. From the repository root, for example:

```powershell
python devtools/test/run_native.py --timeout 180 bin/godot.windows.editor.x86_64.console.exe --verbose --rendering-driver vulkan --path devtools/test/dlss45_project -- --preset=Recommended --mode=performance --frames=600 --sharpness=0.2 --expected-backend=vulkan
```

Repeat using `d3d12` for both backend arguments. Do not use
`--allow-unavailable` for GPU acceptance; that option is for the cloud stub
and explicitly reports a skip. A D3D12-to-Vulkan fallback fails the requested
backend check.

1. Run `Recommended` in `dlaa`, `quality`, `balanced`, `performance`, and
   `ultra_performance` on both backends. Check the actual requested mode and
   preset fields: K=11, L=12, M=13. Requested scaling alone does not prove
   which mode the SDK selected after size rounding.
2. Force `M` and `L` in Quality and DLAA; compare against `K` at identical
   resolution, exposure, camera path and settings. Include landscape,
   ultrawide and portrait windows. Preserve the default sharpness test;
   a separate `--sharpness=0.0` run is an isolation control for NIS.
   Inspect the actual `slSetConstants` camera values during wide/portrait
   and rotated-camera runs: vertical FOV in radians and world-space axes.
   The original camera PR measurements do not automatically validate this
   combined head; keep the check tied to its exact binaries.
3. Record loaded DLL paths, signatures and hashes, `slGetFeatureVersion`,
   driver version, overrides and whether OTA is enabled. A separate process
   with `GODOT_STREAMLINE_DISABLE_OTA=1` isolates installed plugins; restore
   the caller's environment afterward. This flag does not disable driver
   model overrides or the driver's own updater.
4. Use NVIDIA App's `Alt+Z -> Statistics -> Statistics View -> DLSS` overlay
   to save actual model evidence, as NVIDIA recommends. Preserve the exact
   overlay text. If it cannot distinguish the active generation, report
   "M/L requested; active model unconfirmed". Do not change global driver
   preferences; an authorized, temporary application profile is a separate
   control, with the original settings restored afterward.
5. Compare thin geometry, moving edges, disocclusion, ghosting, flickering,
   HUD/text and resize transitions. Record GPU time and VRAM; do not assume
   that the new model improves frame rate. Then run a sustained scene and
   mode-switch test and retain the logs and captures.

The scene's JSON and `RUN_COMPLETED` record describe configuration and
execution. They do not certify image quality or active model identity.
Continue ordinary 2X FG/Reflex, RR, DDGI and native-module regression tests
after the SR-only runs. Viewport captures omit FG intermediate frames;
use a presented-frame capture for basic generated-frame visual acceptance.

## 4. Narrow the strict Vulkan failures

The target machine uses Vulkan 1.4. Record loader, GPU API, header and
validation-layer versions separately. The "1.2" in the feature-chain fix
names the promoted feature group; its rule also applies on Vulkan 1.4.
Keep the current Vulkan version for acceptance.

Keep the validation layer and synchronization validation enabled; record its
version and verify that it actually loaded. Follow
[the layer setup](../kb/tooling/vulkan-sync-validation.md). Save full VUID,
object/handle, first occurrence, command sequence and stack where available.

The separate Vulkan correction prevents chaining the Vulkan 1.2 aggregate
feature struct together with promoted float16/int8, buffer-device-address
and memory-model structs. Verify device creation with and without Streamline,
then check that the matching pNext VUID disappears while PT, RR and FG remain
available. It does not address every validation category.

For NIS, the verified SDK shaders declare RGBA32F storage output while the
engine uses RGBA16F. In the SDK source, an input tagged `eOnlyValidNow` can
also cause a private clone/copy; its GENERAL-to-transfer transition can
produce an empty source access mask. Capture that exact sequence before
changing engine lifetimes. An outer engine barrier cannot repair an internal
SDK barrier. A safe engine-side experiment needs distinct input/output,
format conversion and resize/lifetime checks; retagging an aliased input as
immutable is insufficient.

Keep NIS on/off and FG on/off as separate controls. Track default-NIS
sync/format errors, FG swapchain/layout/semaphore errors and no-Streamline
platform errors separately. Preserve the five existing graphics fixes.

## 5. Isolate D3D12 debug-layer creation

The no-Streamline path normally uses an Agility `ID3D12DeviceFactory` and
its debug interface. The Streamline path bypasses that factory, uses the
system debug entry point and interposes `D3D12CreateDevice`. Thus the earlier
no-SL/SL comparison also changed the device-creation path.

Run each row normally and with `--gpu-validation`, on the same adapter and
with the same Agility files:

| Runtime/control | Device path |
| --- | --- |
| No Streamline | Normal Agility factory |
| No Streamline, diagnostic-only build | Force the existing legacy fallback |
| Streamline 2.10 | Existing interposed legacy path |
| Streamline 2.14.16 | Existing interposed legacy path |

For the diagnostic-only build, retain the initial `LoadLibraryW` calls for
D3D12, DXGI and optional DComp. In `_init_device_factory()`, insert a temporary
`return OK;` after those loads and before the factory-selection code. This
function returns `Error`, not `bool`. Do not return at the function entry:
that would bypass required DLL initialization and invalidate the control.
Verify non-null module handles and a null `device_factory` before the normal
initialization continues. Do not delete/replace Agility DLLs, and do not
submit this diagnostic change as a fix.

Capture `OutputDebugString` through DebugView/WinDbg at startup: the engine's
device info queue is installed after creation and misses earlier messages.
Record factory presence, adapter LUID, feature level, requested IID, first
HRESULT, actual backend, loaded `d3d12.dll`, `D3D12Core.dll`,
`d3d12SDKLayers.dll` and `sl.interposer.dll` paths/versions/hashes, and the
modules owning the invoked function pointers. The interposer's exported
`D3D12GetDebugInterface` forwards to the system implementation; switching
that function pointer alone is not an established fix.

If legacy fails without SL, investigate runtime/debug-layer compatibility
first. If only the interposed path fails, reduce it to a minimal device
creation reproduction. Old 2.10 also fails in the existing report, so avoid
calling this a proven 2.14 regression.

## Completion record

For every row record `commit / binary hash / runtime / driver / requested
backend / actual backend / requested preset / active-model evidence /
result / log and capture paths`. Keep previous failures and reruns distinct.
Use pass, fail, skip and unconfirmed according to the actual evidence.

Cloud verification before handoff: 85 checks and 18 typed SR callback
captures passed; both changed Streamline/renderer clients compiled as real
Windows AMD64 objects with Vulkan and D3D12 enabled. The API smoke and
15 manifest checks passed. The scene parsed and ran on an older prebuilt
Linux dummy engine with DLSS explicitly unavailable; six negative controls
failed as intended. Class XML validation passed with all module/platform
inputs (existing sample-parity notices remain). This is not a full build or
GPU acceptance of the new integration head.

The existing strict validation failures remain open until retested and
resolved or explicitly accepted with a documented scope. Review can proceed
as Draft; this work order does not authorize merge or release.
