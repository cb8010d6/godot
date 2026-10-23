# Windows / RTX runtime validation for NVIDIA-RTX/godot PRs 17 and 18

This folder contains a local validation fixture and reproducible capture tooling.
See `RESULTS.md` for measured results and unresolved gates.

## Versions

- Base: `135dff3887a3d2ccf45cafbd9bdffa7b718e1e76`.
- PR 17: `2ccecd2d10d2304e442dc8fb94a6878cd61d08be`.
- PR 18: `0b50d914deb01928f4985b555e4765f8fa16b43b`.
- SDK distribution: NVIDIA Streamline 2.10.0, matching the bundled header version.
- SDK archive and installed DLL hashes: `logs/sdk-manifest.json`.
- Hardware and driver inventory: `logs/hardware.json`.

## Method

`prepare_variant.py` reads the two affected production files directly from the
specified Git commits. It adds the same capture code to each variant. It records
production and instrumented source SHA-256 hashes and the full local source patch.
The capture code records arguments and return values immediately after the real
`slSetConstants` call, and return values after the real `slEvaluateFeature` calls.
It also queries the real `slDLSSGGetState` in FG mode. No SDK function is mocked.

These are instrumented development builds of the full Windows rendering path,
with GDScript, glslang, and the fallback text server modules. They use a live
Vulkan window and real RTX rendering, not Godot's headless rendering driver.
Unneeded modules and the editor are disabled to keep build cost down.

The fixtures cover:

- Horizontal FOV 90 degrees with KEEP_WIDTH and vertical FOV 90 degrees with
  KEEP_HEIGHT, at 1:1, 16:9, 21:9, and 9:16.
- Identity, Y +90, X +90, Z +90, and 0.73 radians about normalized (1,2,3),
  with camera position (3,-7,11).
- DLAA, DLSS SR, path tracing with DLSS Ray Reconstruction, and DLSS SR with FG.
- A short camera and object motion sequence, captured at eight points.

For each static case, 40 frames settle the viewport and SDK state, then eight
frames are sampled. FG uses 120 settling frames, a 60 FPS limit through the
Streamline Reflex API (not Engine.max_fps), and requests focus for its own test
window to provide a stable presentation interval after resizing. FOV is independently checked against both the camera's
projection matrix and the analytical aspect-ratio formula. Basis vectors are
checked against independent Rodrigues rotations, as well as the actual Camera3D
transform. SDK success and screenshots are separate checks from numerical
correctness. Unsupported or failed features remain failed or unverified.

## Re-run

Workspace layout: this directory is `validation/`, the checkout is `source/`,
the Python environment is `.venv/`, and the SDK archive is
`sdk/streamline-sdk-v2.10.0.zip`.

From the workspace root in PowerShell:

```powershell
./validation/build_variant.ps1 baseline
./.venv/Scripts/python.exe ./validation/run_runtime.py baseline --setup-sdk
./validation/build_variant.ps1 pr17
./.venv/Scripts/python.exe ./validation/run_runtime.py pr17
./validation/build_variant.ps1 pr18
./.venv/Scripts/python.exe ./validation/run_runtime.py pr18
./validation/build_variant.ps1 both
./.venv/Scripts/python.exe ./validation/run_runtime.py both
./.venv/Scripts/python.exe ./validation/analyze.py
```

Each run stores the executable hash, actually observed loaded SDK module hashes,
engine/GPU metadata, stdout/stderr, numerical case references, and original PNGs
under `captures/<variant>/<mode>/`. Build logs and source manifests are under
`logs/`. There is a five-minute timeout per process; timeout is a failure.

The local instrumentation is reproducible and kept outside the PRs. Restore the
two source files to the unmodified base after captures with:

```powershell
./.venv/Scripts/python.exe ./validation/prepare_variant.py baseline --no-instrument
```

## Scope limits

Passing the camera metadata checks does not demonstrate a performance or ghosting
improvement. Original screenshots and motion samples support visual inspection,
not a quantitative image-quality comparison. Timing from instrumented builds is
not a performance benchmark. Coverage is centered perspective cameras with
normal orthonormal transforms, Vulkan, and float precision; asymmetric,
orthographic, double precision, and Direct3D 12 require separate runtime runs.

No remote PR metadata, comments, or branches are changed by this tooling.

## Public evidence package

This package publishes all 16 final run manifests, case references and analyses,
full runtime logs (gzip-compressed), original source patches, hardware/SDK
manifests, and comparison sheets. Machine-specific paths are replaced by logical
placeholders; private originals remain untouched. Uncompressed PNG hashes in
`logs/image-inventory.json` identify all 336 originals. Eight representative
original rotated-camera PNGs (base/combined, four modes) are included here;
the other original PNGs are retained privately. The aspect and motion sheets
contain additional captured images resized for inspection. No SDK DLLs or
engine binaries are redistributed.

Decompress `runtime.log.gz` beside each manifest before analyzing published
captures offline. To re-run, copy these tools and the project into a workspace's
`validation/` directory, use a sibling `source/` checkout with the pinned commits,
create `logs/` and `bin/`, and provide the SDK archive and Python/SCons environment
described above. The measured build used Python 3.12.10 and SCons 4.11.1.
The report's log references refer to the corresponding `.gz` files where present.
