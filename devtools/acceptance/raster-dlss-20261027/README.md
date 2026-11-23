# Raster / DLSS SR acceptance evidence, 2026-10-27

This is a selected evidence bundle for native source commit
`b3763e7c7ef8e621e2e19018589e5a022aba1f82` and game program commit
`3d51851c6eec09ff4cb8a2b0f818e837d06ca4e8`. The comparison uses official
Godot 4.7.2 with FSR and the candidate 4.8 build with DLSS SR, alongside two
native-resolution controls. It concerns raster rendering and super-resolution;
it does not establish results for ray reconstruction or frame generation.

## Records and interpretation

* [matches/matrix.json](matches/matrix.json) records ten complete automated bot
  matches, all `FUNCTIONAL_PASS`: skate and ski, one and four players, each
  with 4.7.2 FSR and 4.8 DLSS, plus one-player skate native controls for both
  engines. The corresponding directories contain result, observer, frame and
  log records. This is one run per case. The 60 FPS cap and VSync, different
  reconstruction algorithms and sharpness settings prevent a causal speedup
  claim; these are not human input or latency measurements.
* [strict](strict) contains two 12-second PLAY-scope validation runs, one and
  four players, each classified `STRICT_STARTUP_CLEAN`. Module sampling was
  incomplete: respectively 46 successful snapshots and 2 failures, and 55
  successful snapshots and 1 failure. The recorded module observations apply
  only to successful snapshots, not every instant of the runs.
* [regression/matrix.json](regression/matrix.json) records three forced
  result-transition repetitions classified `FORCED_RESULTS_TARGET_NOT_OBSERVED`.
  This is a targeted diagnostic, not proof the error cannot occur elsewhere.
  [failure](failure) retains the earlier failing run, trace and controls; it
  should not be confused with the candidate's subsequent results.
* [burst/matrix.json](burst/matrix.json) records four separate `STARTUP_ONLY`
  diagnostics (skate/ski, one player, FSR/DLSS). Each captured 19 frames;
  first-to-last spans were approximately 1.966, 1.999, 1.933 and 1.934 seconds
  in matrix order. The first and last original PNGs are included for each case;
  capture metadata includes the omitted frames' hashes. These sparse images do
  not certify temporal quality, full-match behavior or human feel. The separate
  full-match screenshots are snapshots, not synchronized frame comparisons.
* [export/export-matrix.json](export/export-matrix.json) and
  [export/natural-exit-matrix.json](export/natural-exit-matrix.json) report PASS
  for the recorded export and natural-exit startup checks. The latter used
  `--fixed-fps 60`; it is a startup check and is not a full-match or performance
  result. Its three original startup screenshots are included.

## Provenance and privacy

The selected text is redacted: local paths, identifying strings and private
resource names may be replaced, and JSON/JSONL formatting may be normalized.
Other fields remain the recorded observations. Redaction can change text bytes
and can remove context; inspect each file's `transformation` in
[manifest.json](manifest.json). The PNGs are original, byte-identical captures,
not edited or resized for this bundle. The manifest records both original and
published byte counts and SHA-256 hashes for each selected source file. Original
records remain separately retained; hashes alone do not make them available or
prove capture authenticity. The manifest does not hash itself or this README;
[SHA256SUMS](SHA256SUMS) covers all bundle files except itself.

The bundle omits executables, libraries, SDK payloads, game assets, profiles
and TLS material. The PNGs depict rendered gameplay and are provided as visual
evidence rather than as redistributable game assets.

## Delivery review and reproducibility tools

The GPU records above are from 2026-10-27. The separate `cpu` directory records
the later delivery review: six required CPU checks pass in the isolated fixture
environment, with commands, exit codes and input hashes. The original failing
suite remains under `original-environment-failure`; an empty injected Git config
value was lost during Windows environment restoration. Only the fixture child
environment was adjusted; product files, test assertions and user Git settings
were not changed. These CPU runs do not add GPU or human-play evidence.

`tools/observer.gd` is the byte-identical observer used for the ten matches;
it requires the matching game program, its autoloads and a visible GPU window.
Set `RS_TEST_MODE=1`, use separate imported projects/profiles, apply the exact
settings from the report, and omit the FG plugin at process initialization for
the candidate. Invoke each engine with `--path <game> --script <observer.gd>
--rendering-method forward_plus --rendering-driver vulkan --resolution 1600x900
-- --game=skate --demo=1 --map=0 --observe-output=<evidence-directory>`.
Use ski / four bots for the remaining matrix cases. Do not add fixed-delta or
forced-exit flags when comparing complete natural matches. This observer emits
raw measurements; it does not independently certify a pass. The original
controller additionally checks frozen inputs, real viewport state, captures,
finite results, exit, process ownership and cleanup.

`tools/reprojection_math_reference.py` retains the original CPU geometric
arithmetic; its local trace-input path alone is adapted to the bundled relative
trace matrix. It models rounded float products with Decimal inverses, not
compiled Godot C++.
Neither tool proves human feel, temporal quality, latency or model identity.
