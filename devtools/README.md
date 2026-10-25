# Developer tools

Scripts for setting up a PC, building, testing and releasing this Godot
build (upstream Godot + NVIDIA DLSS / path tracer + PhysX 5). They are
Windows PowerShell scripts; run those from PowerShell or cmd in the
repository root, not from Git Bash. Portable upgrade checks also use
Python, C++ and a headless GDScript fixture.

The maintenance rules (syncing upstream, NVIDIA and PhysX, conflict rules,
versioning) are in [CUSTOM_BUILD.md](../CUSTOM_BUILD.md). Feature notes:
[DDGI.md](../DDGI.md), [PATHTRACER_TESTING.md](../PATHTRACER_TESTING.md).

| Folder | Script | What it does |
| --- | --- | --- |
| `setup/` | `setup_dev_windows.ps1` | Sets up a new PC in one go (below) |
| `build/` | `build.ps1` | Builds the editor, the .NET editor, the export templates or a whole release |
| `test/` | `smoke.ps1` | The smoke tests every merge and release must pass |
| `test/ddgi/` | `ddgi_tests.ps1`, `ddgi_eval.py` | DDGI measurements: flicker, light switch, weather, scrolling, GPU time, baking, comparison shots |
| `docs/` | `update_class_docs.ps1`, `check_class_docs.py` | Keeps the class reference (editor help) complete |
| `package/` | `package_editor_win64.ps1`, `package_templates_win64.ps1` | Release zips and export template `.tpz` files |

Everything a script writes goes to `devtools/out/` (not tracked), except the
build (`bin/`) and the packages (`dist/`).

## Set up a new PC

1. Install Git, Python 3.9+ and Visual Studio 2022 (or the Build Tools) with
   the "Desktop development with C++" workload. For PhysX GPU dynamics also
   the CUDA Toolkit 12.8 (`winget install Nvidia.CUDA --version 12.8`), for
   the C# editor the .NET SDK 10 or newer satisfying `modules/mono/global.json`.
2. Clone into a short folder (MSVC can't handle paths over 260 characters,
   and the build's deepest files add about 150), then run the setup:
   ```
   git clone -b nvidia-dlss-physx https://github.com/Diginaat/godot.git godot-rtx
   cd godot-rtx
   powershell -ExecutionPolicy Bypass -File devtools\setup\setup_dev_windows.ps1 -Build
   ```

The setup checks the tools, installs SCons and Godot's D3D12 build
dependencies, sets the reference git remotes (`upstream`, `origin` =
NVIDIA-RTX, `physx`) and detects `fork` from the actual clone URL, builds
the PhysX, Blast and Flow
SDKs once in a `physx-sdk` folder next to the repository (about 20 minutes
the first time), writes the SDK paths into `custom.py` and, with `-Build`,
builds the editor. Run it again any time: finished steps are skipped.

An existing personal fork URL is preserved. Recognized reference repositories
have push disabled, regardless of their local remote name. The remote setup
does not fetch or publish anything; inspect `git remote -v` before pushing.

Options: `-Mono` (also the .NET editor), `-NoGpu` (PhysX without CUDA),
`-PhysXDir <folder>` (build the SDKs somewhere else).

`custom.py` holds this PC's build options and is read by every SCons run, so
builds need no long command lines. It is not tracked by git.

DLSS is optional: in the editor, click **Get NVIDIA DLSS...** to install
NVIDIA's runtime files next to it.

## Build

```
devtools\build\build.ps1                         # editor
devtools\build\build.ps1 -Mono                   # .NET editor, with C# glue and assemblies
devtools\build\build.ps1 -Target templates       # release and debug export templates
devtools\build\build.ps1 -Target templates -Mono # .NET export templates
devtools\build\build.ps1 -Target release         # all six builds a GitHub release needs
```

For the pinned Godot 4.8 beta 1 upgrade, add `-VersionStatus beta1` to the
chosen command. The script applies it to native and managed builds and
restores the caller's environment afterward. Direct SCons builds use
`GODOT_VERSION_STATUS=beta1`; do not edit upstream `version.py`.

`-KeepGoing` reports all compile errors in one pass (scons `-k`); `-Jobs N`
limits the parallel jobs. All builds use `production=yes`: staying on one
flag set keeps them incremental. Close any editor running from `bin\` first,
or linking fails with "Access is denied".

## Test

```
devtools\test\smoke.ps1          # standard editor
devtools\test\smoke.ps1 -Mono    # .NET editor
```

| Test | Passes when |
| --- | --- |
| PhysX, game and editor | `PhysX 5.x initialized` in the log, exit code 0, no errors |
| Path tracer, Vulkan | a screenshot is written, no "Raytracing not supported" |
| DDGI, interior | the test scene renders and measures, no errors |

The PhysX tests use Wild Ox Studios' example project; clone it next to this
repository (`git clone https://github.com/uno1982/godot-physx-example`) or
pass `-PhysXExample <folder>`. Without it they are skipped. Logs and the
screenshot are in `devtools\out\smoke`.

### Portable upgrade checks

```sh
python devtools/test/test_raytracing_builders.py
python devtools/test/test_streamline_manifest.py
python devtools/package/streamline_manifest.py --archive /path/to/streamline-sdk-v2.14.16.zip
python devtools/test/upgrade_smoke.py --godot bin/<built-editor>
python devtools/test/upgrade_smoke.py --export-editor bin/<built-editor> --template bin/<built-template> --require-physx --require-blast --require-flow
python devtools/test/test_csharp_smoke.py --godot bin/<built-mono-editor> --dotnet dotnet
```

The Windows `smoke.ps1` runner contains native tests in a Job Object and closes
remaining test descendants after each run. It also checks for accumulated NGX
updaters before and after a launch. This avoids repeated GPU tests leaving driver
update processes resident. It does not change driver settings or manage unrelated
processes. `python devtools/test/run_native.py --timeout 300 <native-engine> ...`
provides the same lifetime guard for a separate native test; arbitrary application
launchers are outside its tested scope.

The headless smoke checks existing API/serialized enums, the non-Windows
Streamline stub, and DDGI scene/resource round trips. Add `--require-physx`,
`--require-blast`, `--require-flow`, and `--require-mono` to require modules
compiled into that editor; otherwise unavailable modules are explicit skips.
It does not render, bake probes, or validate a Windows DLL runtime.

The template mode exports a real PCK and uses normal executable-name-matched
autoload, without unsafe path overrides. The C# smoke compiles with the local
SDK and verifies actual PhysX typed and dictionary queries in a running editor.

`devtools/test/test_windows_packages.py` runs the actual packaging scripts
in isolated Unix/PowerShell 7 fixtures (`PWSH` selects the executable). Their
EXE/DLL files are test data, so these checks prove archive behavior and
failure handling, not native Windows execution. Actual public archives are
also checked automatically by the packaging scripts; the standalone scanner
is `streamline_manifest.py --public-package <zip-or-tpz>`.

`powershell -File devtools/test/test_windows_build.ps1` (or `pwsh`) checks
the standard/.NET six-build orchestration, SDK selection, glue failure
handling, and version-status environment cleanup with isolated mocks.

`powershell -File devtools/test/test_windows_remotes.ps1` checks the remote
setup against isolated local Git repositories, including personal fork URLs,
reference push guards, ambiguous origins, and repeated setup. It never
fetches or pushes.

See [UPGRADE_4_8_BETA1.md](UPGRADE_4_8_BETA1.md) for exact source pins,
recorded verification and the remaining Windows/RTX validation checklist.

### DDGI measurements

```
devtools\test\ddgi\ddgi_tests.ps1 -Test flicker    # static interior: brightness and flicker
devtools\test\ddgi\ddgi_tests.ps1 -Test switch     # lights switched: how fast the GI follows
devtools\test\ddgi\ddgi_tests.ps1 -Test weather    # a storm rolls in: patchiness and lag
devtools\test\ddgi\ddgi_tests.ps1 -Test scroll     # moving camera: error left by scrolling
devtools\test\ddgi\ddgi_tests.ps1 -Test bench      # GPU time per DDGI pass at 1080p
devtools\test\ddgi\ddgi_tests.ps1 -Test bake       # bake and load the interior volume
devtools\test\ddgi\ddgi_tests.ps1 -Test compare    # the README comparison shots
devtools\test\ddgi\ddgi_tests.ps1 -Test all
```

Add test project arguments with `-Extra`, for example
`-Extra "--quality=3","--realtime=1"`. What each number means, and the
results so far, are in [DDGI.md](../DDGI.md). The image measurements need
Pillow and NumPy (`python -m pip install pillow numpy`).

## Class reference

```
devtools\docs\update_class_docs.ps1
```

Updates the XML of the editor help from the built editor, restores the docs
of classes the build doesn't include, lists every fork entry that still has
no description and validates the XML. `python devtools\docs\check_class_docs.py -v`
only does the listing.

## Release

1. Bump `CUSTOM_VERSION`, update the versioning table in CUSTOM_BUILD.md and
   the version line in README.md, commit ("chore(release): prepare x.y.z").
2. `devtools\build\build.ps1 -Target release` (the version stamp is the commit).
3. `devtools\test\smoke.ps1` and `devtools\test\smoke.ps1 -Mono`.
4. Package:
   ```
   powershell -File devtools\package\package_editor_win64.ps1
   powershell -File devtools\package\package_editor_win64.ps1 -Mono
   powershell -File devtools\package\package_templates_win64.ps1
   powershell -File devtools\package\package_templates_win64.ps1 -Mono
   ```
   The scripts print the release tag and title. Public packages never contain
   NVIDIA Streamline / DLSS files; games exported with the editor get them
   from the editor's folder.
5. Push the branch and the tag, then
   `gh release create <tag> --target <full commit SHA> --title "<title>" dist\...`.
