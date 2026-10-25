# Godot 4.8 beta 1 / Streamline 2.14.16 upgrade

This is an integration branch, not a release. Keep the published branches and
`CUSTOM_VERSION` unchanged until the Windows hardware checks below pass.

Native Windows follow-up on 2026-10-25 is recorded in
[Windows acceptance](WINDOWS_ACCEPTANCE_2026_10_25.md). All six MSVC targets,
both smoke variants and installed standard/.NET Debug/Release exports ran.
Real RTX tests cover both backends, SR/DLAA, Vulkan PT/RR, ordinary 2X FG,
Reflex, DDGI and native SDKs. Strict Vulkan and D3D12 debug-layer checks still
fail, and active DLSS 4.5 model identity is unconfirmed. Read the tested commit
and separate-regression boundaries before assigning those results to a PR.

## Source audit

| Source | Locked revision | Role |
| --- | --- | --- |
| Diginaat `dev` | `25f6a147ed8ca36d521638ba2b5fe1715a3cbdaa` | Clean starting tree, custom build 0.7.3 |
| Diginaat default `nvidia-dlss-physx` | `0d2488e2912b7004cd510906f5a6a61b09c6cf5f` | Two README-only commits ahead of `dev` |
| Official Godot | `4d10419cacd6d3009976e8f9fd3abd970fd58018` | 4.8 beta 1; 172 upstream commits after the previous sync |
| NVIDIA Godot | `135dff3887a3d2ccf45cafbd9bdffa7b718e1e76` | Existing RTX integration, already an ancestor of `dev` |
| Streamline `v2.14.16` | `625db07d4bca5abc67d781c42af7e7fb0761f1b6` | Complete official header set, replacing 2.10.0 |
| PhysX module | Existing vendored module and adaptations | Unchanged SDK pin `ovphysx-0.5.11` (PhysX 5.10.0) |

The runbook's remote names describe its original maintainer setup. This
upgrade instead keeps `diginaat` as a read-only base, `upstream` as official
Godot, `origin` as NVIDIA, and `physx` as the module reference. Only `fork`
points to the personal repository used for this branch. All reference push
URLs are disabled. Check the actual URLs with `git remote -v` before pushing.
No issue, PR, release, or tag is created by the upgrade procedure.

To reproduce this integration, clone the upgrade branch from the personal
fork rather than the unchanged published Diginaat branch:

```text
git clone --branch upgrade/godot-4.8-beta1-streamline-2.14.16 <your-personal-fork-url> godot-rtx
```

The upstream merge had one textual conflict, in `CODEOWNERS`. Both the
upstream build-system entries and NVIDIA driver entries were retained;
stale ownership for an absent driver was removed. The stricter upstream
validator now also covers the fork's tooling, knowledge base, and PhysX
module. Its file list uses NUL delimiters so Unicode paths are not mistaken
for Git's quoted display strings.

Rendering changes were reviewed beyond the textual conflict:

- Keep shader container version 5 and the fork's reflection extensions. The
  new upstream `container_header` member is host state; it does not change
  the serialized reflection layout and does not require another cache bump.
- Keep the upstream acceleration-descriptor `writes_amount` fix and the
  existing single insertion of ray-query features into each Vulkan chain.
- Keep the custom Forward+ PT renderer, DDGI passes, fog setup, async hit
  groups, BLAS lifetime guards, and all existing module registrations.
- Keep both sides of upstream Mono ABI changes, the native-runtime export
  plugin, and the standard/.NET editor and template build flows.

## SDK update and packaging

The official `streamline-sdk-v2.14.16.zip` is **276016170 bytes**, SHA-256:

```text
32041e51db0cab709a271b72a352281b690c2abbd669a827809401a5dd23956b
```

Its 24 public headers and license are vendored with provenance in
`thirdparty/streamline/README.godot`. No runtime binary is committed.
`drivers/streamline/streamline_runtime.h` is the shared version, download,
checksum, and release-file manifest used by the installer, exporter, and
private packaging. The verified release still contains the same 19 runtime
and license files under `bin/x64/`.

The offline manifest check also compares the entire vendored public header
inventory and license against the verified ZIP, allowing only CRLF-to-LF
normalization. A matching version number alone is insufficient.

The installer retains explicit license/download/browser confirmation and
validates the pinned size, checksum, and required entries before installing.
Public editor ZIPs and template TPZs are checked for NVIDIA runtime DLLs;
private packaging keeps its existing Nsight Perf exclusion. Exported games
may copy the installed release runtimes. Missing NVIDIA files must not stop
the editor, ordinary rendering, PT without RR, or PhysX export.

SDK 2.14.16 activates deprecation diagnostics on the existing global tagging
typedef. A narrow compatibility alias keeps the same function type and
existing tagging/preference behavior. This upgrade does not change tagging
semantics or add Neural Rendering, 6X MFG, or Dynamic MFG controls.

## Reproducible checks

Native builds require Python 3.9+, SCons 4.4+, and `zstandard` for Python
older than 3.14. Managed builds require .NET SDK 10 selected from
`modules/mono`, where `global.json` lives. Keep `version.py` byte-identical
to the pinned upstream version; use `GODOT_VERSION_STATUS=beta1` for direct
SCons or `-VersionStatus beta1` with the build script.

The managed API and tooling target `net10.0`. Existing C# projects that
still target `net8.0` must be retargeted and rebuilt; selecting SDK 10 alone
does not make a net8.0 project reference a net10.0 API. This is an upstream
framework requirement, not an optional SDK feature introduced by this fork.

Portable checks, from the repository root:

```sh
python misc/scripts/validate_codeowners.py --unowned
python tests/python_build/validate_builders.py
python devtools/test/test_raytracing_builders.py
python devtools/test/test_streamline_manifest.py
python devtools/package/streamline_manifest.py --archive /path/to/streamline-sdk-v2.14.16.zip
g++ -std=c++17 -Wall -Wextra -Werror -I. devtools/test/streamline_api_smoke.cpp -o /tmp/streamline_api_smoke
/tmp/streamline_api_smoke
python devtools/test/upgrade_smoke.py --godot bin/<built-editor>
python devtools/test/upgrade_smoke.py --export-editor bin/<built-editor> --template bin/<built-template> --require-physx --require-blast --require-flow
python devtools/test/test_csharp_smoke.py --godot bin/<built-mono-editor> --dotnet dotnet
```

Use PowerShell to run `devtools/test/test_windows_build.ps1` and
`devtools/test/test_windows_remotes.ps1`; set `PWSH`
and run `python devtools/test/test_windows_packages.py` for Unix-hosted
PowerShell packaging fixtures. Their executable/DLL placeholders check
workflow and archive contents, not native Windows runtime behavior.

The C# smoke uses the just-built local SDK packages. It creates an isolated
project, compiles the custom bindings, initializes PhysX CPU, and checks both
the dictionary and typed ray-query results against known geometry.

Add `--require-physx --require-blast --require-flow --require-mono` to the
`upgrade_smoke.py` command only for a build that includes them. Optional
module skips are reported explicitly. The headless test checks serialized enums, API
registration, DDGI resource/scene round trips, and volume lifecycle. It
does not render or bake probes. On non-Windows it exercises the actual
compiled Streamline stub; it does not simulate Windows DLL loading.

The template mode exports an actual PCK and launches a copied production
template by normal PCK autoload. The same fixture is a main scene in both
modes and writes saved resources to isolated `user://`. Production path
override protection is not disabled. This is a GDScript game check; the
managed game export below exercises a separate boundary.

For the Linux managed export check, use the C# smoke's generated project,
create its solution with `dotnet new sln --name ManagedSmoke --format sln`
and `dotnet sln ManagedSmoke.sln add ManagedSmoke.csproj`, and allow NuGet.org
alongside the local engine feed to restore self-contained runtime packs.
Configure Linux Debug/Release presets with the matching custom Mono
templates, `binary_format/embed_pck=false`, and
`dotnet/embed_build_outputs=false`. Run the editor's `--export-debug` and
`--export-release`, then launch each exported executable normally with the
dummy renderer. Check the export log for errors as well as the exit code.

Both exported managed games passed with SDK discovery removed from the
runtime environment; `hostfxr` loaded from their exported data directories.
The Linux fixture explicitly supplies the native SDK `.so` siblings from
`bin/`. The existing runtime export plugin handles Windows libraries, so
automatic Linux SDK redistribution is not established by this check.
Windows distribution and embedded-PCK exports subsequently passed the local
Agent checks described in the Windows acceptance record above.

For a pinned, offline Windows runtime check, set
`GODOT_STREAMLINE_DISABLE_OTA=1` in the test process environment before
starting the engine. This opts out of both Streamline OTA downloads and
loading its downloaded plugins; the default remains unchanged. It does not
disable NVIDIA App/driver overrides. Record `slGetFeatureVersion` results,
loaded runtime files and the requested preset separately from the SDK ZIP.
An SDK version or a successful capability query does not identify the active
AI model or prove that generated frames were presented.

An SDK header smoke compile, Windows cross-compile, package fixtures, and
source-generator build cover distinct boundaries. None is a substitute
for the native Windows and GPU checks below. Build and test logs go to
`devtools/out/upgrade/` (untracked); run the commands again for a new commit.

### Linux build profile used here

Editor checks used `platform=linuxbsd target=editor tests=yes dev_build=yes
optimize=none debug_symbols=no x11=no wayland=no`. Both standard and Mono
editors were built; the Mono build includes the real CPU PhysX, Blast and
Flow SDKs at the existing pin. No SDK path is written into tracked files.

Template checks use `target=template_release` / `template_debug`,
`production=yes optimize=none debug_symbols=no lto=none linker=lld x11=no
wayland=no`, with those same native SDKs, adding `module_mono_enabled=yes`
for the .NET variants. These are compilation/runtime-validation builds, not
performance or release-size measurements. Vulkan remains enabled.

The first release-template attempt used GNU ld and exposed an inherited
archive-order backreference when both desktop display backends are disabled.
The Vulkan object and symbol existed; the late server reference was not
rescanned. LLD 19 linked the same objects successfully. There is no engine
source patch or Vulkan exclusion for this host configuration. A normal
Linux desktop build can instead enable X11; Windows/MSVC remains a separate
build. Production templates retain their normal path-override restrictions.

## Windows / local Agent handoff

Use a fresh working tree on this branch, with no uncommitted changes. Keep
the existing SDK pins and PhysX adaptations. Build the real dependencies,
not stub libraries. Do not overwrite a live editor's DLLs while testing.

1. Run `devtools\setup\setup_dev_windows.ps1 -Mono`, including CUDA 12.8
   and the existing PhysX GPU, Blast, Flow, D3D12 and AccessKit dependencies.
   Confirm the .NET SDK resolves to 10+ from `modules\mono`.
2. Run `devtools\build\build.ps1 -Target release -KeepGoing -VersionStatus beta1`.
   This must build both editors, all four templates, glue and C# assemblies.
   Record compiler versions, final Git SHA, flags, and binary `--version`.
3. Run `devtools\test\smoke.ps1`, then `-Mono`, and the portable headless
   smoke with all four `--require-*` flags on the matching .NET editor.
4. Test clean private editor copies with no Streamline files, only a
   partial installation, the previous SDK runtime, and a complete 2.14.16
   release runtime. Exercise Vulkan and D3D12, request DLSS and FG, and
   verify normal fallback without crashes or unwanted viewport jitter.
   No runtime test should depend on the installed editor being modified.
5. With the complete SDK, check DLAA, SR Quality/Performance, PT+RR, FG,
   and Reflex on/off. Inspect actual Streamline calls and errors; include
   landscape, ultrawide, portrait, and rotating/moving camera cases. These
   checks measure integration correctness, not an assumed FPS improvement.
6. Run the existing PT scene matrix and DDGI flicker, switch, scrolling,
   bake/load and comparison suites in `PATHTRACER_TESTING.md` and `DDGI.md`.
   Compare at fixed settings against a build from the original `dev` SHA.
   Confirm D3D12 raster fallback and baked DDGI, plus Vulkan dynamic DDGI.
7. Run PhysX CPU and CUDA GPU example scenes, Blast destruction, Flow,
   and exported standard/C# games. Confirm the correct native libraries
   are copied with and without installed NVIDIA runtimes.
8. Package standard/.NET editors and templates with the existing scripts.
   Public archives must pass the runtime exclusion check. Install the TPZs,
   export and run real projects, including an embedded PCK and C# game.

Only after the required checks pass should the integration be marked
release-ready. Draft review must disclose the remaining failures. Keep hardware-specific failures separate
from build failures and from unavailable tests.

## Recorded verification

The source upgrade, portable checks, native builds and out-of-tree SDK checks
are recorded here as they finish. Windows runtime and GPU checks remain
pending; no image-quality or performance improvement is claimed.

All six native binaries were rebuilt at integration code commit
`0af58f0a62f05a901e99dde96f1654c35a6bdbc1`, report that revision in their
version strings, and passed the editor/PCK checks again. Local build logs,
binary hashes and results are in `devtools/out/upgrade/final-verification.json`.
Managed export commands and logs are in
`devtools/out/managed-export-validation/`.

| Check | Observed result | Boundary |
| --- | --- | --- |
| Standard Linux editor | Built; 79 headless API checks | Optional native SDKs absent, actual non-Windows Streamline stub |
| Linux Mono editor with native SDKs | Built; 88 headless API checks | PhysX/Blast/Flow/CSharp registration and DDGI lifecycle/serialization |
| Linux standard release template | Built; real PCK 87 checks | Normal production autoload, real native SDK libraries |
| Linux Mono release template | Built; real PCK 88 checks | GDScript PCK and registered managed/native API, not a C# export |
| Linux standard debug template | Built; real PCK 87 checks | Normal production autoload, real native SDK libraries |
| Linux Mono debug template | Built; real PCK 88 checks | Same production autoload; managed runtime supplied explicitly |
| Native engine unit suite | 1465 cases, 442079 assertions passed | Three inherited default skips; required socket permission supplied |
| Managed API / GodotTools | Debug and Release assemblies and SDK packages built | .NET SDK 10.0.402; target net10.0 |
| Source generators | 43/43 passed, no skips | Actual generated custom engine API |
| C# engine smoke | Build/run passed, known geometry hit by both query APIs | Real PhysX CPU dispatcher; four custom managed bindings |
| Linux C# game exports | Debug and Release export/run passed | Real self-contained publish and exported runtime; SDK `.so` dependencies supplied by fixture |
| Ray-tracing shader builder | 3/3 passed | Decompression, five-stage ordering and sparse stages; no GPU shader evaluation |
| Manifest / provenance | 15/15 passed; official ZIP comparison passed | Size, digest, release inventory, all 24 vendored headers and license |
| Windows build workflow | 6/6 PowerShell fixture cases passed | SDK selection, all six targets, error handling and version environment |
| Windows remote setup | 8/8 scenarios, 10 real Git repositories passed | Exact fork URLs preserved, reference push guards and idempotency; no network operations |
| Windows package workflow | 7/7 PowerShell fixture cases passed | Public standard/.NET ZIP/TPZ and curated private runtime, negative cases |
| Enabled Streamline clients | Actual Windows-target driver and DLSS effect objects compiled | MinGW-w64 GCC 14, real Windows/Vulkan/D3D12 headers; not a full Windows link/run |
| Native SDK smoke | PhysX 60 simulation steps, four Blast tests, Flow CPU loader/device passed | GPU/CUDA and Windows SDK binaries untested |
| Class documentation | No XML warnings or errors | Existing sample-parity notices remain; no new public API was added |

The upstream source-generator test dependency restore reports existing NuGet
advisories for its test-only `System.Security.Cryptography.Pkcs` 9.0.10
dependency. No upstream package pin was changed for this integration.
