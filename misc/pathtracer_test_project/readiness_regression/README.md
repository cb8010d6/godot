# RT readiness regression

This visible Vulkan fixture checks recorded RT commands and live shader state.
It requires a new writable `--output=<directory>` after `--`. Four phases verify
real green/blue pixels, fresh ready serials and TLAS/dispatch counts, including
two independent views, a source change and a pipeline-variant change. A final
RT-only invalid identifier must report failure instead of ready. Keep that
intentional compiler error in the original log. SKIP is not a GPU pass.

Editor/tools binaries retain the direct script entry:

```powershell
$NativeRunner = (Resolve-Path 'devtools/test/run_native.py').Path
& python -B $NativeRunner --timeout 180 $Editor --path $Project --script res://readiness.gd --rendering-driver vulkan `
  --rendering-method forward_plus -- --output=$NewEvidenceDirectory
```

Production templates built with path overrides disabled reject --path,
--script and --main-pack. Test their release statistics through a normal
exported PCK. Do not weaken the build's security settings for this regression.
The project registers `RTReadinessRegression` as its MainLoop and supplies an
empty bootstrap main scene: Main::setup requires a main scene before
Main::start selects the custom MainLoop. The bootstrap has no script/rendering
nodes, and the custom SceneTree retains all fixture assertions.

## Windows PCK workflow

Set these variables explicitly before running:

- `GODOT_EDITOR`: matching editor executable.
- `GODOT_RELEASE_TEMPLATE`: matching production release EXE in a dedicated
  writable runtime directory, including its normal native dependencies. Use a
  prepared copy or same-volume hard-linked runtime; never patch linked files.
- `GODOT_ACCEPTANCE_ROOT`: selected work/output location with sufficient space.

No SDK download or NVIDIA DLL is required by this fixture. The commands copy
only the four small text fixture inputs, not an existing import/shader cache.
They write a same-basename PCK beside the unchanged template executable:

```powershell
$NativeRunner = (Resolve-Path 'devtools/test/run_native.py').Path
$Editor = (Resolve-Path -LiteralPath $env:GODOT_EDITOR).Path
$Template = (Resolve-Path -LiteralPath $env:GODOT_RELEASE_TEMPLATE).Path
$Fixture = (Resolve-Path 'misc/pathtracer_test_project/readiness_regression').Path
if (-not $env:GODOT_ACCEPTANCE_ROOT) { throw 'Choose GODOT_ACCEPTANCE_ROOT first.' }
$Work = Join-Path $env:GODOT_ACCEPTANCE_ROOT ('readiness-' + [guid]::NewGuid().ToString('N'))
$Project = Join-Path $Work 'project'
$Capture = Join-Path $Work 'capture' # Must not exist before the fixture starts.
$Pack = [IO.Path]::ChangeExtension($Template, '.pck')
if (Test-Path -LiteralPath $Pack) { throw 'Choose a fresh dedicated runtime directory; preserve the existing PCK.' }
New-Item -ItemType Directory -Path $Project | Out-Null
foreach ($Name in @('project.godot', 'readiness.gd', 'bootstrap.tscn', 'export_presets.cfg')) {
    Copy-Item -LiteralPath (Join-Path $Fixture $Name) -Destination (Join-Path $Project $Name)
}
$env:APPDATA = Join-Path $Work 'profile/roaming'
$env:LOCALAPPDATA = Join-Path $Work 'profile/local'
$env:TEMP = Join-Path $Work 'profile/tmp'
$env:TMP = $env:TEMP
$env:GODOT_STREAMLINE_DISABLE_OTA = '1'
foreach ($Folder in @($env:APPDATA, $env:LOCALAPPDATA, $env:TEMP)) {
    New-Item -ItemType Directory -Path $Folder -Force | Out-Null
}
$TemplateHash = (Get-FileHash -LiteralPath $Template -Algorithm SHA256).Hash
& python -B $NativeRunner --timeout 180 $Editor --headless --editor --path $Project --import
if ($LASTEXITCODE -ne 0) { throw 'Fixture import failed.' }
& python -B $NativeRunner --timeout 180 $Editor --headless --editor --path $Project --export-pack 'Release readiness' $Pack
if ($LASTEXITCODE -ne 0) { throw 'PCK export failed.' }
& python -B $NativeRunner --timeout 180 $Template --rendering-driver vulkan --rendering-method forward_plus --verbose -- "--output=$Capture"
if ($LASTEXITCODE -ne 0) { throw 'Release fixture failed.' }
if ((Get-FileHash -LiteralPath $Template -Algorithm SHA256).Hash -ne $TemplateHash) { throw 'Template bytes changed.' }
```

The existing standard-library run_native.py wrapper owns the Windows Job, waits
for the real process exit, enforces the 180-second failure timeout and checks NGX
cleanup. All three stages use it. Do not invoke a Windows GUI EXE directly and
then trust PowerShell $LASTEXITCODE: it can retain a previous result. Preserve
the original stdout, wrapper exit code and cleanup evidence.
Do not add a frame-count or wall-clock success criterion. The fixture's own
120-second deadline is a failure bound. Do not replace a missing output with a
controller's exit-0 verdict.

Inspect actual PCK payloads: the exact text readiness.gd, global-class cache,
project.binary main_loop_type/main_scene, bootstrap remap and converted scene.
Require summary PASS, all five phases and four original PNGs, actual native
version/API/GPU and exit0. `pending_observed=false` cannot prove a cold transition.
PNG assertions and manual inspection supplement each other. Recorded trace work
does not prove a GPU-completion fence, physical present, RR, DLSS or FG.

## Measurement boundary

A private precursor with this class registration/bootstrap approach was run
with unmodified native commit `8a7364bf6c52022eab78ed33298e7539449e8c88` on an RTX
4060 Laptop GPU. Import/export/run exited0 (5.187/4.985/21.531 seconds); the
actual PCK payload, five phases, pixel assertions and intentional failed-shader
state were audited. The earlier no-main-scene launch remained a failure.
This public fixture change still needs import/export/runtime regression on its
exact committed tree; it is not retroactively covered by the private precursor.
