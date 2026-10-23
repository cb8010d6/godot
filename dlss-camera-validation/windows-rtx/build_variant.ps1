param(
    [Parameter(Mandatory=$true)]
    [ValidateSet('baseline','pr17','pr18','both')]
    [string]$Variant
)
$ErrorActionPreference = 'Stop'
$validationRoot = $PSScriptRoot
$workspaceRoot = Split-Path -Parent $validationRoot
$validationPython = Join-Path $workspaceRoot '.venv\Scripts\python.exe'
$sourceRoot = Join-Path $workspaceRoot 'source'
& $validationPython (Join-Path $validationRoot 'prepare_variant.py') $Variant
if ($LASTEXITCODE -ne 0) { throw 'Preparing source variant failed' }
Push-Location $sourceRoot
try {
    & $validationPython -m SCons platform=windows target=template_debug arch=x86_64 use_streamline=yes vulkan=yes d3d12=no opengl3=no accesskit=no modules_enabled_by_default=no module_gdscript_enabled=yes module_glslang_enabled=yes module_text_server_fb_enabled=yes debug_symbols=no optimize=speed_trace windows_subsystem=console -j6 *> (Join-Path $validationRoot "logs\build-$Variant.log")
    if ($LASTEXITCODE -ne 0) { throw "Build failed: $Variant" }
    Copy-Item -LiteralPath (Join-Path $sourceRoot 'bin\godot.windows.template_debug.x86_64.exe') -Destination (Join-Path $validationRoot "bin\$Variant.exe")
    Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $validationRoot "bin\$Variant.exe")
} finally {
    Pop-Location
}
