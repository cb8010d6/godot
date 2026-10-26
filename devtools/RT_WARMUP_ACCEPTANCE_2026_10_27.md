# RT startup warm-up and Vulkan Streamline follow-up — 2026-10-27

**The warm-up implementation and bounded Windows acceptance pass. Vulkan RR
with the automatic/F preset still fails strict validation.** This is an
experimental candidate, not complete RTX or release sign-off.

## Identities and environment

| Item | Actual identity |
| --- | --- |
| Final built engine | `d29e7065306d670a643ca0ea7a362c4b38cea3c5` |
| Game program inputs | `3d51851c6eec09ff4cb8a2b0f818e837d06ca4e8`; critical files match Git blobs |
| Readiness implementation first editor | `5470fe8dde76c43c16f67db64020319ea82ce788` |
| Startup FG control and bounded game tests | `8a7364bf6c52022eab78ed33298e7539449e8c88` |
| Private ownership/evaluation diagnostics | `c3260c00904c7e3fa7b22811ef4bd5ccd950ebfa` / `8b1055662793954959fe5ce8b11843437af0adc3`; tracing removed from final engine |
| OS / CPU / RAM | Windows 10 Pro 19045; Ryzen 9 7940H; 31.22 GiB visible RAM |
| GPU / driver | RTX 4060 Laptop GPU, 8188 MiB; 610.88 |
| Build tools | VS 2022 Community 17.14.43; selected CL 19.44.35229.0; Windows SDK 10.0.26100.0 |
| Managed SDK | .NET SDK 10.0.402; projects target net10.0 |
| Vulkan | Driver API 1.4.341; independently loaded VVL 1.4.366; no full Vulkan SDK environment configured |
| Runtime distributions | Official Streamline 2.14.16 / NGX RR 310.9.16; complete 2.10.0 / NGX RR 310.5 used only as a separate diagnostic |

Builds use Jobs 2, GPU tests run serially, and working data/caches use the selected
non-system workspace volume. Original projects and the normal desktop shortcut
remain unchanged. A separately hashed playable copy and the two NVIDIA shortcuts
use the final native candidate.

## Changes and reproduced behavior

The renderer now exposes per-viewport pending/failed RT shader counts, recorded
dispatch count and a fresh recorded-frame serial in release as well as editor
builds. Existing enum values remain unchanged. Readiness uses the live pipeline
variant and acknowledges an actually recorded trace command; an attempted or
rejected dispatch cannot certify a viewport. Failed shader preprocessing retains
an explicit failure rather than being mistaken for a ready default material.

The game pauses its clocks and physics behind a loading cover while every active
PT view records two fresh, coherent ready snapshots. Cancel, timeout and shader
failure have recovery behavior. Unsupported engines/drivers and non-PT views
use their explicit not-applicable path. This is a rendered-scene loading criterion,
not a GPU fence, physical-present proof or an offline precompile of every future
camera/LOD/material combination.

The new public fixture includes class registration, a bootstrap main scene and
a PCK preset. Production templates keep path overrides disabled. A custom
MainLoop still needs the earlier main-scene startup guard; the original failed
external-script and no-main-scene attempts remain preserved.

`GODOT_STREAMLINE_DISABLE_DLSS_G=1` omits the FG plugin at process initialization,
skips its function queries and reports FG unavailable. The exact opt-in does not
change default initialization or SR/RR/NIS/PCL/Reflex selection. It cannot be
enabled by toggling FG Off after the swapchain already exists.

## Build and functional acceptance

| Test | Result and measured boundary |
| --- | --- |
| Six final Windows targets | **PASS**, 352.344 s: standard/Mono editor, template_debug and template_release; clean d29 checkout, Jobs 2 |
| Frozen binary identities | **PASS**, 12 actual main/console version queries, including correct `.mono.` qualifier; independent byte copies |
| Standard editor smoke | **PASS**, 30.672 s; repository PhysX, Vulkan PT and separate DDGI cases |
| Mono editor smoke | **PASS**, 27.078 s; same repository cases |
| Four installed-template exports | **PASS**, standard/Mono × Debug/Release; matching installed TPZ, real D3D12 fixture, own natural exit |
| Managed self-contained games | **PASS** with SDK removed from each child process environment; the test machine still has an SDK installed |
| Public readiness PCK at d29 | **PASS**: import 6.250 s, export 5.265 s, release GPU run 5.281 s; five phases, real pending observed, four pixel stages, intentional failed shader detected |
| Game Observer controls | **PASS**: 5470 skating normal 1 player; 8a skating 2/4 players, skiing 4 players, first/second-gate cancel, accelerated injected deadline and RT shader failure; clocks/physics checked while paused |
| Actual full-game PCK at d29 | **PASS**: installed-template export, exact RT include and compiled warm-up/remap/class audit; unchanged game code/assets |
| Actual production entry | **PASS**: Vulkan PT/RR request and D3D12 raster request; three original captures per API, no external script/path/frame guard, own RSExit flow |
| Missing runtime DLLs | **PASS** for no-SL editor/release readiness and four installed-template games; this is not a new `streamline=no` compilation |
| Official Godot compatibility | Official 4.7.2 import and 17 headless checks pass for game 3d; forced-exit cleanup warnings remain retained; A738 rendered compatibility is historical, not relabelled d29 |

The repository build command is:

```powershell
devtools/build/build.ps1 -Target release -KeepGoing -Jobs 2 -VersionStatus beta1
```

Smoke uses the repository `devtools/test/smoke.ps1` logic with only frozen-binary
and output-path redirection; standard and `-Mono` cases have separate full logs.
Template validation uses actual installed TPZ lookup. Native source, package,
SDK and test inputs are identified by SHA-256 in the evidence manifest.

Existing build warnings include unavailable optional ANGLE libraries, vendor
warnings and the upstream source-generator test dependency Pkcs 9.0.10
NU1902/NU1903 warnings. They are retained and not reported as warning-free builds.

## Vulkan synchronization diagnosis

1. After RTSS was exited, the no-SL control with verified filtered layers no
   longer reproduced the prior PRESENT_AFTER_WRITE diagnostic. The old fixture
   still fails its separate merged-instance-count assertion; it is not rewritten
   as a whole-fixture pass. NvSPcap remains observed in both controls.
2. Same-binary SDK214 SR A/B: default loaded FG plugin retains pacer/fake-swapchain
   layout errors with FG interpolation Off; process-startup FG omission is strictly
   CLEAN in the bounded Quality/Recommended/NIS-off case. This is a scoped SR
   workaround, not an ordinary FG or RR pass.
3. Real-game RR with FG omitted still produces four WAW and four original 09600
   messages across two contexts. All 16 supplied host-tag image handles differ
   from the eight error-image handles. Actual RR calls return eOk in non-Off mode.
4. A public single-view motion fixture reproduces two WAW and two original 09600
   messages with SDK214: actual RR evaluation, eight tags, 160 SDK samples and
   49 frame records/captures complete. Private game content is not required.
5. A matched complete-SDK210 run is CLEAN with actual RR calls confirmed. Another
   old-runtime repeat lost the device before reaching any RR tags; subsequent
   command-pool errors are fallout after the fence failure. A stable production
   downgrade is not established.
6. Requested RR Preset D is strictly CLEAN in the single-view fixture; F reproduces
   the WAW/layout errors. These are actual RR evaluations, not RR-disabled controls.
   Preset requests are not a direct readback of neural-network weight identity.

7. The D compatibility combination also passes strict actual-game single-player
   and four-player scenes. The runs contain respectively two and five traced RR
   contexts (including the lobby), each with eight tags and a first non-Off/eOk
   evaluation. All four game viewports independently report fresh live-ready
   RT state. SDK probe getters cover IDs 1/2 only; there is no direct join from
   SL IDs to Godot viewport paths or neural-weight readback. These are bounded
   checks, not long-term stability, every-frame or quality parity certification.
   The automatic/F failures remain unchanged.

The reproducible compatibility combination uses the existing project setting
`rendering/streamline/dlss_ray_reconstruction_preset="D"` together with process
startup `GODOT_STREAMLINE_DISABLE_DLSS_G=1`. FG is unavailable in that process.
This is an optional preset/feature-selection workaround, not a repair of F's
internal synchronization. Default engine and game RR selection remains automatic.
A separate local RR-D shortcut/project/profile provides this option without
changing the normal or automatic-preset playable copy; its final d29 launcher
startup and owned-child cleanup also pass.

Read-only NVAPI at this checkpoint reports base/global SR, RR and FG overrides
Off (0). Queried application profiles return -166 (not found); unavailable
settings return -160 and are not converted into zero. No driver settings were
written. Earlier snapshots with overrides enabled remain historical results.

The published SDK automatically resets history on first feature creation or
mode/size/preset changes before forwarding the same constants to NGX. Therefore
the host's initial reset=false alone does not explain this fresh-process F
failure. See the [pinned implementation](https://github.com/NVIDIA-RTX/Streamline/blob/v2.14.16/source/plugins/sl.dlss_d/dlss_dEntry.cpp#L354).
The upstream [RR report #126](https://github.com/NVIDIA-RTX/Streamline/issues/126)
has similar first-evaluation hazards on a different configuration; it supports
investigation but does not independently prove the cause of this machine's errors.

SDK lazy retention until plugin unload is documented behavior. Missing explicit
SR/RR frees alone is not evidence of a leak. Viewport-ID reuse/history and
mid-session VRAM reclamation remain separate unmeasured risks. An explicit free
would require GPU-completion and shutdown-order work; none was added unsafely to
the viewport destructor.

## Feature matrix and limits

| Feature | Acceptance status |
| --- | --- |
| Godot 4.8 beta 1 | Integrated and six Windows targets build; locked upstream `4d10419cacd6d3009976e8f9fd3abd970fd58018` |
| Streamline 2.14.16 | Integration/build/runtime identities checked; complete Vulkan strict acceptance **fails** |
| DLSS SR / DLAA / 4.5 request policy | Prior d37 hardware results and original K/M/L indicators retained; 8a SR startup control measured; full model/mode matrix not rerun at d29 |
| RR | Real GPU operation confirmed; automatic/F strict **FAIL**; D compatibility is separately scoped above |
| Ordinary FG 2X / Reflex | Prior acceptance retained; current default feature selection unchanged; no new d29 generated-frame or end-to-end latency pass |
| Vulkan PT / DDGI | Final standard/Mono smoke and readiness GPU cases **PASS**; PT and DDGI are separate modes |
| D3D12 | Four final exported fixture runs and actual game startup **PASS**; this fork does not implement a D3D12 RT pipeline |
| PhysX | Final repository fall/settle and exported physics fixtures **PASS**; separate CPU-versus-GPU dynamics attribution is not newly certified |
| Blast / Flow | Included in final builds; dedicated new functional/GPU cases **NOT EXECUTED**; prior evidence retains its own SHA/scope |
| MFG / Dynamic MFG | RTX40 2X-only policy retained; no advertised RTX40 6X or Vulkan Dynamic MFG; RTX50-only capabilities **NOT TESTED** |
| Long stress / all content / image quality / latency | **NOT EXECUTED** in this bounded follow-up; no performance or ghosting improvement claim |

The source/runtime distribution and models are different evidence layers. No
private SDK, vendor DLL, model weights or credentials are part of this source
delivery. Public template exclusion checks pass. Existing third-party notices
and licenses remain in force.

The prior A738 material-only playable copy remains available for local rollback.
The startup FG control is opt-in and can be unset to restore default selection;
RR automatic selection remains the default. The native diagnostic tracing is
absent from final production source. Cloud merges and material fixes were not
reverted or replaced wholesale.

Scoped warm-up code and the reproducible diagnostics can be reviewed. The game
PR remains experimental/draft; automatic/F Vulkan RR strict failures prevent
complete RTX/release sign-off. Newer documentation-only commits do not relabel
the tested native SHA. Codex assisted implementation, tests and reports; the
reported GPU logs and images came from actual local executions.

Full sanitized records and selected original PNGs: [evidence snapshot](acceptance/rt-warmup-20261027/README.md).
Earlier results remain in the independent [A738 material snapshot](acceptance/pt-materials-20261026/README.md)
and [original RTX stabilization snapshot](acceptance/stabilization-20261026/REPORT.md).
