# Godot 4.8 raster + DLSS versus 4.7.2 — 2026-10-27

**Limited automated gameplay acceptance passes. Human play-feel acceptance is
pending.** The target is Vulkan Forward+ rasterization with DLSS upscaling,
compared with official Godot 4.7.2. PT, RR, DDGI and FG are outside this round.
Their earlier results and failures remain at their original tested commits.

Runtime evidence in this report was recorded on 2026-10-27. Later documentation
and publication do not constitute a fresh GPU rerun or an updated-driver test.

## Identities and conditions

| Item | Measured identity |
| --- | --- |
| Built native source | `b3763e7c7ef8e621e2e19018589e5a022aba1f82` |
| Native editor SHA-256 | `c6c7af301169c21df68b9cce0a419b660bbe445df0719b911cc6a1cc64602c62` |
| Official baseline | 4.7.2 stable, `ed1daf0bf`; executable SHA-256 `ab1824f85bfd8e0e4128182c000c4003a3e042245b2967848d089b2a04b22424` |
| Game program | `3d51851c6eec09ff4cb8a2b0f818e837d06ca4e8` in the separate game repository; no program edits in this round |
| Game baseline being migrated | `209897f4573208e02df52c4c929731a27d3527b1` |
| Official 4.8 beta 1 base | `4d10419cacd6d3009976e8f9fd3abd970fd58018` |
| OS / CPU / RAM | Windows 10 Pro 19045; Ryzen 9 7940H; 31.22 GiB visible RAM |
| GPU / driver | RTX 4060 Laptop, 8188 MiB; 610.88 |
| Build tools | VS 17.14.43, CL 19.44.35229; Windows SDK 10.0.26100.0 |
| Vulkan / Streamline | Driver API 1.4.341; Streamline 2.14.16; strict checks loaded VVL matching manifest 1.4.366 |

Two independently imported, byte-checked project copies use the same code and
assets. Both request 1600×900, quality 2, Jolt 120 Hz, 60 FPS and VSync, HDR off,
raster lighting, NIS off and FG off. The 4.8 process additionally omits the FG
plugin at startup (`GODOT_STREAMLINE_DISABLE_DLSS_G=1`) and disables OTA.
Driver override readback reported SR/RR/FG overrides off; no driver setting was
written in this round. Power was Balanced; these are sequential laptop runs.

FSR2 Quality uses scale 0.67 and sharpness 0.2; DLSS Quality uses 2/3 and
sharpness 0.0. These are different reconstruction algorithms and settings,
not identical render inputs. Bot trajectories and timing are not matched replays.

## A real gameplay defect and its repair

The previous d29 engine emitted a `Projection::invert` final-pivot error at the
results transition of a natural four-player skating DLSS match. Three shortened
forced transitions reproduced it. One-run controls with official FSR2, d29 native
and d29 FSR2 did not. A separate opt-in diagnostic build tied an occurrence to
SR's reverse reprojection inverse. The captured float matrix is mathematically
invertible, but ill-conditioned: exact-input determinant about 0.42927,
condition number about 1.22e8; float elimination reached a zero pivot.

The repair constructs SR's reverse mapping from the original camera factors
instead of inverting the combined float matrix. Forward reprojection, motion
vector decoding and the actual RR path remain unchanged. There is no artificial
token reset, identity fallback or general singular-camera repair. See the
[numerical finding](../kb/tooling/dlss-sr-factorized-reprojection.md).

The fixed engine passes three forced-transition repetitions and the natural
four-player match in the complete matrix below. This establishes that the target
error was not observed in these reruns; it does not certify all history cuts.
The offline 72-point geometric reference models rounded float products with
Decimal factor inverses; it does not execute Godot's native C++ inverses.

## Real builds, games and startup

| Check | Result and boundary |
| --- | --- |
| Standard editor rebuild | PASS, 64.860 s, clean b376 checkout, Jobs 2 |
| Standard debug/release template rebuild | PASS, 120.407 s total, Jobs 2; four waited main/console version queries |
| Short strict Vulkan SR | PASS, one/four-player skating, 12 s PLAY each; VVL and SDK modules sampled, no reported VUID/synchronization/engine error |
| Forced results regression | PASS for the target error: 0 occurrences in three 15 s PLAY trials; diagnostic timing only |
| Full natural bot matches | PASS, all ten cases below; actual PLAY, finite scores, RESULTS and natural RSExit |
| Private A/B startup | PASS, official 4.7.2 and b376; real Hub receives game hello, three original captures each, natural exit and owned-process cleanup |
| Standard release export | PASS, actual installed TPZ, import 21.563 s, PCK inclusion/remap audit; code and assets unchanged |
| Exported production entry | PASS, Vulkan raster DLSS request accepted, three original captures and natural exit; no external script/project/main-pack override |
| Short image bursts | Capture checks PASS, four single-player sport/engine pairs, 19 original frames each over 1.933–1.999 s; temporal quality remains unaccepted |
| Human controls, BLE, phone pairing and feel | NOT TESTED; separate playable A/B entries prepared |
| .NET, D3D12, missing-DLL fallback, other upscaling modes/maps | NOT rerun or accepted in this narrowed round |

The production export startup uses `--fixed-fps 60` and game screenshot arguments
at simulation seconds 1/4/8. It is a startup/export check, not a real-time
performance or full-match comparison. Full-match timing below has no fixed-delta
override. All GPU workloads run serially. Owned child processes are closed and
later census checks recorded no owned survivors/NGX updater; immediate closing
membership lists are retained separately.

Full-match PLAY post-draw intervals, milliseconds; only eligible foreground
frames after warmup and excluding capture/observation windows are summarized:

| Sport / players / mode | p50 | p95 | p99 | Eligible / total |
| --- | ---: | ---: | ---: | ---: |
| Skate 1 / 4.7.2 FSR2 | 16.671 | 18.744 | 19.858 | 4499 / 6427 |
| Skate 1 / 4.8 DLSS | 16.639 | 19.276 | 20.386 | 4196 / 6103 |
| Skate 4 / 4.7.2 FSR2 | 16.571 | 22.370 | 24.918 | 4762 / 6702 |
| Skate 4 / 4.8 DLSS | 16.442 | 22.617 | 25.463 | 4866 / 6796 |
| Ski 1 / 4.7.2 FSR2 | 16.614 | 18.380 | 19.457 | 2591 / 4504 |
| Ski 1 / 4.8 DLSS | 16.616 | 18.859 | 19.930 | 2822 / 4745 |
| Ski 4 / 4.7.2 FSR2 | 16.324 | 20.789 | 24.888 | 2593 / 4509 |
| Ski 4 / 4.8 DLSS | 16.851 | 20.054 | 24.246 | 2520 / 4344 |
| Skate 1 / 4.7.2 native | 16.623 | 18.828 | 19.800 | 4188 / 6107 |
| Skate 1 / 4.8 native | 16.629 | 19.162 | 20.267 | 4189 / 6106 |

One capped round per configuration cannot establish equivalent smoothness,
speedup, input latency or long-term stability. Occasional long frames remain in
the raw data, including in the baseline. Screenshots show rendered content;
they do not certify temporal reconstruction quality. Burst diagnostics and their
failures are recorded separately from these timings.

The four successful burst captures span 1.966 / 1.999 / 1.933 / 1.934 seconds
(skate baseline/candidate, ski baseline/candidate). Images are read back during
PLAY and PNG-encoded afterward with a bounded buffer. Selected frames show the
actual course, players and HUD with no observed missing ground/building material
or black frame. Low-rate stills cannot establish smoothness or exclude ghosting
and flicker. The first tool version failed its minimum-frame criterion (4 frames);
the second had a script indentation parse error. Both failures remain recorded.
The third version fixes the tool, without changing game inputs or lowering the
minimum ten frames / 1.7-second span criterion.

## Validation and remaining acceptance

The two short strict checks obtained 46 and 55 successful module samples; a
further two and one sampling attempts failed, respectively. Loaded VVL
SHA-256 was `f0353be5c5339433f5616a242919c724aeba046eca5b08531573818223b9e45a`.
Loader insertion and synchronization validation were confirmed. No sampled FG
or RTSS module was seen. Sampling does not observe every instant. SR mode 3
options returned `sl::eOk` in two/five contexts; this is not independent
model-weight or every-frame Evaluate readback.

The next acceptance decision is how the same sports actually play: responsiveness,
comfort, ghosting/flicker, distant detail and four-player readability. Human A/B
play remains pending. Both entries restore their chosen raster/upscaling settings
on restart, use separate saves/caches and leave the ordinary game untouched.

## Delivery CPU checks

The required game CPU suite was rerun during the 2026-11-24 delivery review:
conventions (zero errors, four existing SIZE warnings), i18n (512 keys, no
missing/extra keys), tool tests (122 and 293 subtests), Ruff, Hub tests (251),
and asset-sync tests (12) pass. Commands, exit codes and before/after input
hashes are retained. These checks do not add GPU or human-play evidence.

The first new CPU run failed four fixture cases before product execution:
Windows test environment restoration dropped an empty injected Git configuration
value while retaining its count/key. The unchanged suite passes in a test-only
subprocess without that injected command configuration. Original failures remain
in the bundle; user/global Git settings and repository tests were not changed.
See the [environment finding](../kb/mistakes/empty-git-config-in-test-environment.md).
Final publication-pointer edits receive separate JSON, diff and privacy checks.

[Evidence and original-image manifests](acceptance/raster-dlss-20261027/README.md)
identify redacted textual copies and byte-identical selected PNGs. Earlier
failures are preserved rather than overwritten. No vendor SDK/DLL/model weights,
private profiles, keys or game assets are included. Reproduce with the pinned
engine/game, separate imported projects and profiles, the settings above and the
published observer; keep strict validation and image-readback runs out of timing.
Native commands were `devtools/build/build.ps1 -Jobs 2 -VersionStatus beta1` and
`devtools/build/build.ps1 -Target templates -KeepGoing -Jobs 2 -VersionStatus beta1`.

For rollback, use a separate checkout of the previous published engine
`abc912706b2b5fb2cfa68523136233c4be45c551` (native d29) or the official baseline.
The SR repair is one independent commit; subsequent report commits do not change
the built native identity. Existing licenses remain unchanged. Codex, including
GPT-6.1 Terra at xhigh as requested, assisted diagnosis and independent reviews;
reported GPU logs and images come from actual local executions. This candidate
is suitable for scoped review and human playtesting, not full RTX/release sign-off.
