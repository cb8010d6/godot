# Godot 4.8 beta 1 / Streamline 2.14.16 stabilization

Work branch: `stabilization/4.8-beta1-sl214`, starting at
`eface96b72e491dda5329388cd308792e0d09872`. That integration head differs
from measured production `08e97fb8a6871cfe39f83a24e2a5813936efd208` only in
diagnostic documentation. Existing production corrections are preserved.

The [fixed-head evidence archive](https://github.com/cb8010d6/godot/tree/fed4abdb965f43eab698933e08fad4d4b31e162b/devtools/acceptance/08e97fb8a6-20261025)
and independent diagnostic/review branches remain intact. Those results do
not validate later native changes. All new runs record checkout state, exact
input hashes, commands and full failure logs. An exit of zero after fallback
or with validation errors is not acceptance.

## Defect register

| Priority | Area | Reproduction / state |
| --- | --- | --- |
| P1 | NIS output format | Vulkan shader declares Rgba32f against RGBA16F view; current baseline reproduces undefined-storage-image values |
| P1 | NIS alias and synchronization | Same input/output resource and volatile clone; baseline WAW includes a transfer clear and clone copy |
| P1 | Base Win32 surface | No-SL baseline reports null hinstance, `01307` |
| P1 | SL Vulkan depth handoff | `oldLayout-01213`, copy-aspect `06663` and pending layout `09600`, including SL2.10 control; attribution pending |
| P1 | SL Vulkan device requirements | SL2.14 low-latency extension dependency `01387` and privateData `04564`; separate from NIS |
| P1 | Vulkan present/FG lifetime | Wait/signal, destroy-swapchain/semaphore, RAW/WAW and threading diagnostics retained; SDK/engine boundary needs isolation |
| P1 | FG multi-viewport ownership | Global dlssg_viewport can alternate; bounded, queryable fallback required |
| P1 | Legacy D3D12 debug | Core/layer mismatch predates beta1 in current dependencies; ordinary and factory paths pass; production fix not claimed |
| P2 | Active SR model | Requested K/L/M policy passes at old head; both backends still need resolved-model evidence |
| P2 | Import/cache | Fresh singleton and Mono safe-save failures retained; isolation is a workaround |
| P2 | Long-run/performance/presentation | Requires fixed-workload GPU/CPU/VRAM sampling and actual presented-frame evidence |
| P2 | Reference game | Independent migration workspace, keeping Jolt and game main unchanged; not executed yet |

## NIS candidate

NIS sharpening uses distinct persistent per-context input/output textures.
DLSS writes RGBA16F input; a separate graph callback reads it and writes
RGBA32F, matching the actual SDK shader. The existing compute copy converts
to the renderer's original RGBA16F destination. No precision default or
public setting changes. Stable tags avoid the volatile input clone; graph
commands express all three dependencies. NIS native-resource caches are
invalidated when the context is destroyed, before renderer texture release.

This allocates 24 bytes per output pixel while NIS is used (about 21.1 MiB
at 1280x720) and adds a conversion dispatch. Performance and lifetime costs
must be measured; no zero-overhead claim. The existing SR/RR/FG/Reflex
options remain independent. This is an implemented candidate until its
actual GPU comparison is recorded below.

Minimal reproduction, using licensed runtimes installed locally:

```powershell
python devtools/test/run_native.py --timeout 180 <editor> --verbose --gpu-validation --rendering-driver vulkan --path devtools/test/dlss45_project -- --preset=K --mode=quality --frames=180 --sharpness=0.2 --expected-backend=vulkan
```

Use the real Khronos layer with sync validation, record the loaded version,
and compare sharpness zero/nonzero and FG off/on. Preserve complete VUID
contexts, actual backend and runtime hashes. Roll back only the NIS fix commit
to compare the alias/format behavior; do not drop the earlier graph/camera
corrections. Independent baseline/FG/SDK errors must remain visible.

## Acceptance boundary

## First NIS hardware comparison

Native source `94c27203b1bf9fb3095316c8020d9ad4727f7b15` built with the
repository's standard-editor command in 38.344 s after removing the three
new deprecated-API calls seen in the earlier build. The original ANGLE
dependency warning remains.

All nine short rendered cases completed on RTX 4060 Laptop / 610.88 with
the requested actual backend: seven Vulkan controls (including no SL,
SL2.14 NIS/FG request combinations and SL2.10 with NIS off/on), plus D3D12
NIS off/on. The nonzero-sharpness cases logged actual formats 96/108
(RGBA16F/RGBA32F), distinct resources and `sl::eOk` from NIS evaluation.
NIS format-mismatch and sync diagnostics were zero in these runs; a real
captured image was inspected. Existing platform/device/depth/present VUIDs
remain, so **strict Vulkan acceptance still fails**.

The fresh fixture copy did not auto-load its native GDExtension. Its optional
probe silently skipped state capture; these runs establish the NIS API,
format/graph and rendered-scene comparison, not foreground FG activation,
runtime module provenance or generated-frame correctness. Correct the fixture
to explicitly load/require its probe and repeat those dependent checks.
Lifecycle/performance testing is still pending. The initial records remain.

## Acceptance boundary

SL 2.14.16, PhysX/CUDA/DDGI/Blast/Flow pins and public-runtime exclusion
rules remain. RTX50, MFG 3X-6X, Dynamic MFG and newer Godot betas are outside
this work. AI assistance covers implementation, diagnostics and reports;
no synthetic GPU evidence or generated pass records are accepted. No RC,
external PR, tag or release is authorized by these local engineering steps.
