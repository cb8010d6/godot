# Windows / RTX acceptance, 2026-10-25

This records measured results and remaining failures. It is not release approval.
The original cloud commits remain intact. Local review branches do not include
every separate graphics correction used by the combined regression build.

## Revisions and intake

| Input | Commit |
| --- | --- |
| Original custom dev | `25f6a147ed8ca36d521638ba2b5fe1715a3cbdaa` |
| Official Godot 4.8 beta 1 | `4d10419cacd6d3009976e8f9fd3abd970fd58018` |
| Stage A merge | `4b97a9fc16fb9160f616258b3c72e1496565177d` |
| Stage B Streamline upgrade | `0af58f0a62f05a901e99dde96f1654c35a6bdbc1` |
| Received cloud head | `afa73e66c3fde2559d158e2caae2f1e08ad89ffc` |
| Final tested native engine | `1381c325931b2f2cb39ed782df5d7b14b91e878d` |

Stage A merges the official pin while preserving the custom fork. Its diff
against the original custom dev is 247 files, +4834/-1272. Stage B and cloud
verification documents add 48 files, +2615/-206 relative to A. The initial
workspace was clean. No new binary runtime, private SDK, key, or unresolved
conflict was found. `version.py` matches the official pin byte for byte.
The one CODEOWNERS conflict retained both sets of valid entries.

All 24 Streamline public headers and the license match the official 2.14.16
archive, allowing only line-ending normalization. Archive size is 276016170
bytes; SHA-256 is
`32041e51db0cab709a271b72a352281b690c2abbd669a827809401a5dd23956b`.
Installer, exporter, verifier and private packager share the 19-file manifest.
Public editor/template archives exclude the private Streamline runtimes.

## Actual host

Windows 10 Pro 19045; Ryzen 9 7940H, 8 cores/16 threads; 32 GiB RAM;
RTX 4060 Laptop 8 GB, driver 610.88. Visual Studio 2022 Community 17.14.42,
MSVC 14.44.35207 / compiler 19.44.35229.0, Windows SDK 10.0.26100.0.
Python 3.12.10, SCons 4.11.1, .NET SDK 10.0.402/runtime 10.0.13.
No standalone Vulkan SDK was installed: repository headers are 1.4.335;
the GPU exposes Vulkan 1.4.341. Strict checks used Khronos layer 1.4.366
nightly `bc5da10620168c5370f82257528c08756e19a7b2`.

PhysX remains pinned to ovphysx-0.5.11 / 5.10.0, with the existing seven
SDK patches. Real CPU/CUDA GPU, Blast and Flow libraries were built using
CUDA compiler 12.8.93, runtime/CCCL 12.8.90. No stub libraries were used.
All task downloads, temporary files and build caches use a non-system drive.
Driver-owned system model-cache access remains separate from those settings.

## Commands and results

Run from the repository root with the real SDK paths configured locally:

```powershell
devtools\build\build.ps1 -Target release -KeepGoing -Jobs 4 -VersionStatus beta1
devtools\test\smoke.ps1
devtools\test\smoke.ps1 -Mono
devtools\package\package_editor_win64.ps1
devtools\package\package_editor_win64.ps1 -Mono
devtools\package\package_templates_win64.ps1
devtools\package\package_templates_win64.ps1 -Mono
```

The final six-target build at `1381c32593` passed in 2436.610 seconds:
standard/Mono editors, standard/Mono Debug templates and standard/Mono Release
templates. Vulkan, D3D12 and Streamline support were compiled together; each
backend was selected at runtime. A separate standard editor and templates
were built without native NVIDIA SDKs and started successfully.

Both final smoke commands passed all four checks (PhysX game/editor, Vulkan
PT, DDGI), in 29.812 and 25.188 seconds. Real production PCK tests passed
83 standard / 84 Mono API assertions for each Debug/Release template.
Installed TPZ lookup, standard embedded PCK export, and Mono self-contained
export/run passed in all four combinations. The Mono exports ran with
SDK discovery removed and passed typed and dictionary PhysX ray queries.
Windows source-generator tests passed 43/43 without skips. The cloud's 1465
Linux engine tests were not rerun as a Windows native test suite.

Warnings were retained, including optional ANGLE dependency notices, inherited
DDGI C4458 and SDK compiler warnings, and the upstream test-only Pkcs 9.0.10
NuGet advisory. Initial incomplete CUDA and export-fixture failures are
retained in the private receipts; their corrected reruns are separate.

## Rendering compatibility matrix

| Feature | Real GPU observation | Limit |
| --- | --- | --- |
| Forward+ | Vulkan and D3D12 rendered | Strict validation failures remain below |
| SR Quality/Balanced/Performance | Both backends, mode changes and resizing rendered | Active model generation/override-resolved preset unconfirmed |
| DLAA | Both backends, actual 1.0 scale | No quality or performance claim |
| Static/moving object | Captures and native control; output phase corrected on regression branch | Image phase is not physical input latency |
| Moving camera | Both backends at 1400x600 and 600x900, 48 captures per run | Does not validate the separate FOV/rotation PR heads |
| Vulkan PT/RR | Glass, emission, custom/dynamic meshes, shadows, guides, two viewports, portrait resize, RR on/off, presets D/E/F requested | Normal run clean; strict SDK/interop diagnostics remain |
| D3D12 PT | Unsupported warning and raster fallback observed | PT is Vulkan only |
| Ordinary FG 2X | Both backends, game mode, actual foreground PID and repeated presented-count 2/eOk | Viewport screenshots omit generated intermediate frames |
| FG lifecycle | Switches, window resize, exit/restart, and two full scene changes passed per backend | No long-duration stress or generated-frame video QA |
| Reflex | Availability, frame IDs and simulation/render/present/GPU timestamps recorded | No LDAT/end-to-end latency measurement |
| DDGI | Vulkan dynamic/scroll/light switch/bake/load; D3D12 baked load | D3D12 dynamic RT DDGI not established |
| PhysX CPU/GPU | Actual dispatchers and CUDA, fall-and-settle; GPU soft body | PGS unsupported soft contact is a reported skip, not full TGS coverage |
| Blast/Flow | Eight real Blast fragments; Vulkan Flow volume readback and rising gas | D3D12 Flow untested; no benchmark claim |
| Missing Streamline | Both backends start and fall back with capabilities false; partial interposer also falls back | Expected missing-plugin diagnostics retained |
| Old Streamline 2.10 | Actual compatible runtime path exercised on both backends | Actual NGX 310.5.0; old runtime need not be unavailable |
| MFG/Dynamic MFG | RTX40 reports max generated frames 1, dynamic false; no 6X control | RTX50 untested; Vulkan Dynamic MFG unsupported |

The complex RR run recorded real feature-state changes: estimated VRAM was zero
initially off and about 50.8 MB after enabling. This is aggregate SDK state,
not independent proof of per-viewport model identity. Guide captures cover
depth, motion, diffuse/specular albedo, normal/roughness and hit distance.

DDGI's equal-setting, one-run comparison used 640x360, 600 convergence frames,
60 measured frames and exposure 4. Pre-upgrade/A/new mean linear luminance
was 0.0459 throughout; flicker standard deviation was about 0.153/0.149/0.170
8-bit levels. These samples establish limited compatibility, not a statistically
significant change or a performance benchmark.

## Runtime identity and restrictions

The 16 release DLL signatures were valid NVIDIA signatures. Actual
`slGetFeatureVersion` reported Streamline 2.14.16 and NGX 310.9.16 for SR/RR/FG.
Loaded files, hashes and requested presets were saved privately. Read-only
NVAPI found global SR/RR/FG overrides enabled, SR/RR Latest presets and MFG
count zero. The driver loaded existing model-set `20318480`. A temporary
per-test profile control was denied with INVALID_USER_PRIVILEGE and was not
saved; no global driver preference was changed.

Consequently DLSS SR is GPU-tested, but **DLSS 4.5 second-generation Transformer
is not confirmed**. SDK version, runtime version, model-set ID and requested
preset do not establish the active AI generation or resolved preset.
`GODOT_STREAMLINE_DISABLE_OTA=1` disables the SDK's OTA/plugin loading preference,
not separate NVIDIA driver updaters or overrides.

## Independent corrections and remaining failures

Graphics corrections stay separate from the two upgrade review branches:

| Commit | Reproduction and change | Regression |
| --- | --- | --- |
| `3e024c0a01` | PR #14 class of one-frame output lag; declare DLSS output write and backend-specific state | About 0.988 extra frames before, -0.004 after, both backends; independent implementation |
| `1050415573` | Exit could free an abandoned RT pipeline twice via shader dependency | Pipeline before owned shaders; six short/long exit tests clean |
| `fcca7536eb` | Inherited PT output/RR guide storage formats mismatched allocations | Matching RGBA16F declarations/allocations; those two VUIDs disappeared |
| `e0c27964e8` | DLSS clear/copy usage and NIS shared RID tagging | Transfer usage, Vulkan GENERAL scope, D3D12 UAV retained |
| `1381c32593` | External callback stage mask was empty | ALL_COMMANDS scope; pre-SDK clear hazard removed |

The independent Windows build fix `5cae5e3046` isolates standard/Mono native
objects and libraries. A shared-cache Mono editor previously selected a
standard template and failed to load the C# game; cold isolated Mono rebuild,
all six targets and installed-template games subsequently passed.

Strict validation is **not passing**. With default NIS sharpening, remaining
SDK command barriers use source access NONE for a clear-to-copy dependency;
an SDK output shader expects RGBA32F against RGBA16F. Disabling NIS sharpening
in a controlled test removes the SYNC and NIS-format messages. FG fake-swapchain
layout/transfer/present/semaphore diagnostics remain, as do inherited Win32
surface-instance/Vulkan feature-chain issues. No-Streamline controls retain
the two platform issues. These errors have not been hidden or all attributed
to one vendor component.

D3D12 with Streamline and `--gpu-validation` fails CreateDevice with
E_INVALIDARG and falls back to Vulkan. The old 2.10 runtime reproduces it;
the no-Streamline D3D12 debug-layer control renders. Ordinary D3D12 works.
This is unresolved interoperability, not a proven new 2.14 regression.

Repeated launches also accumulated 386 delayed NGX updater processes, around
9–10 GiB plus about 2 GiB of console hosts. A separate read-only audit
correlated them with exact test receipts; targeted cleanup of 322 remaining
instances recovered about 16.4 GiB available memory. Downward idle counts and
stable kernel pools support process accumulation, not a proven Godot heap
leak. Native test Job Objects and pre/post updater census now prevent observed
residue; the actual SDK rerun and final smoke runs passed. Arbitrary launchers
and the small process-creation/assignment window are outside that guarantee.

## Review and rollback

Draft review is reasonable; direct merge/release is not recommended while
strict validation and the model/FG visual/physical-latency gaps remain.
No RTX50, 6X MFG, long-run stability, Windows full native unit suite, or
generated-intermediate-frame video acceptance was performed. Earlier PR #17/#18
GPU records apply to their original tested heads; these upgrade results do
not automatically apply those separate camera fixes.

Preserve cloud history and review the isolated graphics fixes independently.
For an unpublished local stack, the saved baseline ref and original cloud
refs allow returning to the exact old build without rewriting published history.
After publication, revert the specific correction; revert the upstream merge
with `git revert -m 1 <merge>` only after reviewing dependent commits and SDK
compatibility. Keep headers, manifest, installer/exporter and runtime aligned.

Godot remains MIT; vendored Streamline headers/license retain their upstream
notices. Runtime redistribution follows `THIRD_PARTY_LICENSES.md`; no private
SDK/DLL is part of these source changes. AI assisted the audit, fixtures,
corrections, measurements and documentation. Real compilers and GPU runs
produced the results; no screenshots, timings or pass records were fabricated.
