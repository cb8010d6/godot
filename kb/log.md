# Update log

## 2026-10-25 (D3D12 diagnostic control correction)

* **Corrected**: the legacy-control work order retains D3D12/DXGI loader
  initialization and uses the actual Error return type. [Finding](/mistakes/d3d12-legacy-control-initialization.md).
* **Boundary**: documentation only; startup results still require the first
  failing call and HRESULT with the intended debug settings.

## 2026-10-25 (DLSS 4.5 SR follow-up)

* **Added**: [DLSS 4.5 SR policy](/tooling/dlss-4.5-super-resolution.md),
  opt-in Recommended preset requests, SDK submission-boundary tests and a
  rendered Windows fixture. Runtime-controlled defaults, RR and ordinary
  FG behavior remain intact.
* **Prepared**: `devtools/DLSS_4_5_WINDOWS_HANDOFF.md`, including exact-head
  builds, RTX40 active-model evidence, strict Vulkan controls and an
  Agility-versus-legacy D3D12 debug-layer comparison. Hardware results remain
  pending on the newly composed candidate; Dynamic MFG is excluded.
* **Learned**: [class reference validation needs module inputs](/mistakes/class-docs-module-inputs.md).

## 2026-10-25 (native Windows acceptance)

* **Measured**: six final MSVC targets, both smoke variants, four installed
  template exports/runs, source generators and the RTX feature matrix.
  [Acceptance record](../devtools/WINDOWS_ACCEPTANCE_2026_10_25.md) identifies
  each tested revision and separate graphics corrections. Strict validation
  failures, active-model uncertainty and untested visual/latency/hardware
  cases remain. The newly composed review head has no exact-build claim.
* **Corrected fixture**: self-contained Mono exports need official Microsoft
  runtime-pack feeds as well as the pinned local Godot packages.

## 2026-10-25 (Windows test process lifetime)

* **Measured**: delayed NGX updater/console children caused about 11 GiB of
  pressure during repeated launches. Exact test-orphan cleanup and native
  job lifetime regression recovered memory without changing drivers/caches.
  [Process finding](/mistakes/ngx-updater-process-accumulation.md).

## 2026-10-25 (Windows smoke fixture)

* **Fixed**: first-import and unpinned-example ambiguity in the default
  Windows smoke. The bundled scene checks a real PhysX body falling onto
  a floor; script errors now fail the runner and single diagnostics retain
  their full text. [Fixture finding](/mistakes/unpinned-physics-example.md).

## 2026-10-25 (build-isolation regression result)

* **Measured on the separate combined regression build**: all six native
  targets rebuilt and all four installed-template games ran, including
  self-contained Mono without SDK discovery. The newly composed stage-A
  review head has not itself been rebuilt; retain that distinction.

## 2026-10-25 (installed Windows packages)

* **Measured**: all four installed-template Debug/Release games exported and
  ran; self-contained Mono games passed without SDK discovery. Editor package
  tags now read the actual beta1 status from the binary rather than version.py.
  [Package version finding](/tooling/windows-package-version.md).

## 2026-10-25 (Windows default .NET export)

* **Found**: a Mono editor resolving the standard template directory after
  mixed incremental builds. Isolate native object/archive module variants;
  [build finding](/tooling/windows-mono-artifact-isolation.md).

## 2026-10-25 (Windows acceptance in progress)

* **Added**: an opt-out for Streamline OTA during pinned offline validation;
  the normal preference flags stay enabled by default. Runtime regression
  checks and the Windows compatibility matrix are still in progress.

## 2026-10-25 (final source and managed exports)

* **Verified**: both Linux editors and all four templates rebuilt at
  integration code commit `0af58f0a62`; editor and real PCK checks passed again.
* **Verified**: actual self-contained C# Debug/Release game exports and startup,
  without SDK discovery. The Linux fixture supplies native SDK shared libraries;
  Windows redistribution, embedded PCK and GPU checks remain pending.
* **Added**: [incomplete managed export fixture](/mistakes/incomplete-managed-export-fixture.md).

## 2026-10-24 (pinned engine and SDK upgrade)

* **Added**: [4.8 beta 1 synchronization](/project/godot-4.8-beta1-sync.md),
  [Streamline SDK validation](/tooling/streamline-sdk-validation.md), and
  mistakes for [sandbox sockets](/mistakes/sandbox-sockets-in-native-tests.md)
  and [managed runtime discovery](/mistakes/managed-smoke-runtime-environment.md).
* **Updated**: source sync log, build prerequisites and beta1 stamping,
  shared SDK/runtime manifest, installer/export/package checks, PT/DDGI
  compatibility notes, URL-based remote protection, and the local Windows/RTX handoff.
* **Validation boundary**: CPU builds, native/headless/API tests and package
  fixtures are recorded separately from unperformed Windows/GPU tests in
  `devtools/UPGRADE_4_8_BETA1.md`. No image-quality or performance claim.

## 2026-10-12 (dark places)

* **Updated**: DDGI.md step 30: no flicker or blotches in dark places;
  new `tunnel` test view.

## 2026-10-12 (moving objects of any shape)

* **Updated**: DDGI.md step 29: moving objects as oriented boxes with exact
  face form factors (0.7.1).

## 2026-10-12 (moving objects vs path tracer)

* **Updated**: DDGI.md step 28: moving objects' light matched against the
  path tracer.

## 2026-10-12 (moving objects, no noise)

* **Updated**: DDGI.md step 27: moving objects lit as spheres by one ray
  per block, no noise.

## 2026-10-12 (moving objects)

* **Updated**: DDGI.md step 26: probes skip moving objects, near-field
  history lets go faster near them (the smears behind a moving ball).

## 2026-10-12 (near-field rays)

* **Added**: [near-field rays](/ddgi/improvements/near-field-rays.md)
  (proposal 12, done), finding [probes put nearby bounce light in the
  wrong place](/ddgi/findings/near-field-blob.md), success
  [near-field rays](/successes/near-field-rays.md), mistakes
  [a test setting in the animation callback](/mistakes/test-setting-in-animation-callback.md)
  and [a long run of an unfit scene](/mistakes/long-run-of-an-unfit-scene.md).
* **Updated**: [test protocol](/tooling/ddgi-test-protocol.md) with the
  bleed view tests (still and animated).
* **Verified**: emissive surfaces as direct lights (previous entry): the
  storm level shows a smooth light pool from the moving sphere.

## 2026-10-12 (emissive lights, work in progress)

* **Added**: references [DDGI papers and reference code](/research/majercik-ddgi-reference.md)
  and [O3DE DiffuseProbeGrid](/research/o3de-diffuse-probe-grid.md).
* **In progress**: emissive surfaces as direct lights in the DDGI apply pass
  (`rendering/global_illumination/ddgi/emissive_lights`), against light
  spots, blocky glow and bleeding from small emitters. Not verified yet.

## 2026-10-12 (least-squares bake)

* **Implemented**: [least-squares baking](/ddgi/improvements/least-squares-bake.md)
  on `dev-ddgi-quality`; [success](/successes/least-squares-bake.md).
* **Reread** the six GI papers for these two features: SDFDDGI's min/max
  checkerboard went into the low resolution apply; Enemies' dilation
  caveat (it creates new leaks) kept probes inside geometry out of the
  solve and its smoothness term.

## 2026-10-12 (low resolution apply)

* **Implemented**: [low-resolution apply](/ddgi/improvements/low-res-apply-directional.md)
  on `dev-ddgi-quality`, default 1/4: DDGI 1.40 -> 1.13 ms at 1080p.
* **Added**: finding [full resolution pass floor](/ddgi/findings/full-res-pass-floor.md),
  mistake [encoding convention mismatch](/mistakes/encoding-convention-mismatch.md).

## 2026-10-12 (second research set)

* **Added**: 6 references (Unity 6 APV, tetrahedral interpolation, CoD:
  Infinite Warfare precomputed lighting, Stupid SH Tricks, GI downscaling,
  FF7 Rebirth GI) and an unread stub for a Zhihu article (HTTP 403).
* **Added**: proposals 9-11 (low-resolution apply with directional output,
  specular occlusion, least-squares baking) and two small ideas.

## 2026-10-12 (scheduler 2x, moving lights)

* **Corrected**: [favored probes and flicker](/ddgi/findings/scheduler-favored-set-stability.md):
  the cause was the 3x rate, not the window; shipped 2x.
  [Mistake recorded](/mistakes/three-runs-of-a-noisy-test.md).
* **Added**: [moving light trailing](/ddgi/findings/moving-light-trailing.md)
  (open issue, two rejected fixes), the emissive step and weather stepping
  tests in [the test protocol](/tooling/ddgi-test-protocol.md).
* **Updated**: sample-driven results in the proposal and the success page.

## 2026-10-12 (mistakes and successes)

* **Added**: [mistakes](/mistakes/) (7) and [successes](/successes/) (6)
  sections, the `Mistake` and `Success` types, and rule 8 in
  [the howto](/kb-howto.md): record both as they happen.

## 2026-10-12 (later)

* **Added**: [DDGI test protocol](/tooling/ddgi-test-protocol.md), from
  the measurements for sample-driven updates: step response with
  `--sun_step`, startup not reproducible, flicker spread over 3 runs,
  A/B with one editor copy per variant, and a storm game-level test with a
  moving emissive object (fixed exposure, `--fixed-fps 60`, averages
  only).
* **Added**: findings [extra code in the apply pass costs](/ddgi/findings/shader-code-cost-without-work.md)
  and [favored set stability](/ddgi/findings/scheduler-favored-set-stability.md).
* **Updated**: [sample-driven updates](/ddgi/improvements/sample-driven-updates.md)
  is implemented on `dev-ddgi-sched`, with results.

## 2026-10-12

* **Initialization**: Created the bundle: project overview, DDGI and XeGTAO
  state, the findings from the XeGTAO work (render graph ordering issue,
  convergence measuring), six GI papers and talks with what they mean for
  DDGI, and a ranked list of DDGI improvement proposals.
