# Exercises the Windows build workflow with isolated command mocks. Requires
# Windows PowerShell 5.1 or PowerShell 7; no compiler, SDK or Windows binary.
# This checks orchestration, not native compilation or editor runtime behavior.
$ErrorActionPreference = "Stop"
$sourceRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
$fixture = Join-Path $sourceRoot "devtools\out\windows-build-$([guid]::NewGuid().ToString('N'))"
$originalDirectory = Get-Location
$originalStatus = $env:GODOT_VERSION_STATUS
$originalExitCode = $global:LASTEXITCODE
$originalPython = Get-Item Function:\global:python -ErrorAction SilentlyContinue
$originalDotnet = Get-Item Function:\global:dotnet -ErrorAction SilentlyContinue
$previousCalls = $global:WindowsBuildTestCalls
$previousFailSdk = $global:WindowsBuildTestFailSdk
$previousFailNative = $global:WindowsBuildTestFailNative
$previousFailGlue = $global:WindowsBuildTestFailGlue

function Assert-BuildCase([bool]$Condition, [string]$Message) {
	if (-not $Condition) { throw "Assertion failed: $Message" }
}

function Reset-BuildCase {
	$global:WindowsBuildTestCalls.Clear()
	$global:WindowsBuildTestFailSdk = $false
	$global:WindowsBuildTestFailNative = $false
	$global:WindowsBuildTestFailGlue = $false
	$env:GODOT_VERSION_STATUS = "caller-status"
}

try {
	New-Item -ItemType Directory -Force (Join-Path $fixture "devtools\build"), (Join-Path $fixture "modules\mono") | Out-Null
	Copy-Item (Join-Path $sourceRoot "devtools\build\build.ps1") (Join-Path $fixture "devtools\build")
	Copy-Item (Join-Path $sourceRoot "modules\mono\global.json") (Join-Path $fixture "modules\mono")
	[IO.File]::WriteAllText((Join-Path $fixture "custom.py"), "# fixture`n")
	# Mock the existing common.ps1 dependency while executing the actual build
	# script unchanged. The call operator accepts these editor scriptblocks on
	# both Windows and Linux, so the fixture needs no executable placeholder.
	$common = @'
$ErrorActionPreference = "Stop"
$RepoRoot = (Resolve-Path "$PSScriptRoot\..").Path
function Get-Editor([switch]$Mono) {
	$isMono = [bool]$Mono
	return {
		$global:WindowsBuildTestCalls.Add([pscustomobject]@{
			Kind = "editor"; Arguments = @($args); Mono = $isMono
			Status = $env:GODOT_VERSION_STATUS; Directory = "$PWD"
		})
		$global:LASTEXITCODE = if ($global:WindowsBuildTestFailGlue -and $args -contains "--generate-mono-glue") { 1 } else { 0 }
	}.GetNewClosure()
}
'@
	[IO.File]::WriteAllText((Join-Path $fixture "devtools\common.ps1"), $common)
	$global:WindowsBuildTestCalls = [Collections.Generic.List[object]]::new()
	function global:python {
		$global:WindowsBuildTestCalls.Add([pscustomobject]@{
			Kind = "python"; Arguments = @($args); Status = $env:GODOT_VERSION_STATUS; Directory = "$PWD"
		})
		$global:LASTEXITCODE = if ($global:WindowsBuildTestFailNative) { 1 } else { 0 }
	}
	function global:dotnet {
		$global:WindowsBuildTestCalls.Add([pscustomobject]@{
			Kind = "dotnet"; Arguments = @($args); Status = $env:GODOT_VERSION_STATUS; Directory = "$PWD"
		})
		$global:LASTEXITCODE = if ($global:WindowsBuildTestFailSdk) { 150 } else { 0 }
		if (-not $global:WindowsBuildTestFailSdk) { "10.0.100" }
	}
	$scriptPath = Join-Path $fixture "devtools\build\build.ps1"

	Reset-BuildCase
	& $scriptPath -Jobs 2
	$pythonCalls = @($global:WindowsBuildTestCalls | Where-Object Kind -eq "python")
	Assert-BuildCase (@($global:WindowsBuildTestCalls | Where-Object Kind -eq "dotnet").Count -eq 0) "standard editor needs no .NET SDK"
	Assert-BuildCase ($pythonCalls.Count -eq 1 -and $pythonCalls[0].Arguments -contains "target=editor" -and $pythonCalls[0].Arguments -notcontains "module_mono_enabled=yes") "standard editor flags"
	Assert-BuildCase ($pythonCalls[0].Status -eq "caller-status" -and $env:GODOT_VERSION_STATUS -eq "caller-status") "omitted VersionStatus preserves caller"
	Assert-BuildCase (-not $global:WindowsBuildTestCalls[-1].Mono) "standard editor version check"
	Write-Host "PASS standard editor without SDK preflight"

	Reset-BuildCase
	& $scriptPath -Mono -Jobs 2 -VersionStatus beta1
	Assert-BuildCase ($global:WindowsBuildTestCalls[0].Kind -eq "dotnet" -and $global:WindowsBuildTestCalls[0].Directory -eq (Join-Path $fixture "modules\mono")) "SDK selection uses global.json directory"
	$pythonCalls = @($global:WindowsBuildTestCalls | Where-Object Kind -eq "python")
	Assert-BuildCase ($pythonCalls.Count -eq 2) "mono native plus managed assembly command"
	Assert-BuildCase ($pythonCalls[0].Arguments -contains "module_mono_enabled=yes") "mono native flags"
	Assert-BuildCase ($pythonCalls[1].Arguments -contains "modules/mono/build_scripts/build_assemblies.py") "managed assembly build"
	Assert-BuildCase (@($pythonCalls | Where-Object Status -ne "beta1").Count -eq 0) "beta1 passed to native and managed"
	$editorCalls = @($global:WindowsBuildTestCalls | Where-Object Kind -eq "editor")
	Assert-BuildCase ($editorCalls.Count -eq 2 -and $editorCalls[0].Mono -and $editorCalls[0].Arguments -contains "--generate-mono-glue" -and $editorCalls[1].Mono -and $editorCalls[1].Arguments -contains "--version") "glue and version use mono editor"
	Assert-BuildCase ($env:GODOT_VERSION_STATUS -eq "caller-status") "successful mono build restores caller status"
	Write-Host "PASS mono SDK selection, glue, assemblies and beta1 restoration"

	Reset-BuildCase
	& $scriptPath -Target release -Jobs 2 -VersionStatus beta1
	$nativeCalls = @($global:WindowsBuildTestCalls | Where-Object { $_.Kind -eq "python" -and $_.Arguments -contains "SCons" })
	Assert-BuildCase ($nativeCalls.Count -eq 6) "release builds all six native targets"
	foreach ($index in 0..5) {
		$expected = @("editor", "template_release", "template_debug")[$index % 3]
		Assert-BuildCase ($nativeCalls[$index].Arguments -contains "target=$expected") "release target order $index"
		Assert-BuildCase (($nativeCalls[$index].Arguments -contains "module_mono_enabled=yes") -eq ($index -ge 3)) "release language selection $index"
		Assert-BuildCase ($nativeCalls[$index].Status -eq "beta1") "release native version status $index"
	}
	Assert-BuildCase (@($global:WindowsBuildTestCalls | Where-Object { $_.Kind -eq "python" -and $_.Arguments -contains "modules/mono/build_scripts/build_assemblies.py" }).Count -eq 1) "release builds managed assemblies once"
	Assert-BuildCase ($env:GODOT_VERSION_STATUS -eq "caller-status") "release restores caller status"
	Write-Host "PASS release six-target standard/mono workflow"

	Reset-BuildCase
	$global:WindowsBuildTestFailSdk = $true
	$failed = $false
	try { & $scriptPath -Mono -Jobs 2 -VersionStatus beta1 } catch { $failed = $_.Exception.Message -match "No compatible .NET SDK" }
	Assert-BuildCase $failed "incompatible SDK rejected"
	Assert-BuildCase (@($global:WindowsBuildTestCalls | Where-Object Kind -eq "python").Count -eq 0) "incompatible SDK fails before native compile"
	Assert-BuildCase ($env:GODOT_VERSION_STATUS -eq "caller-status") "SDK failure leaves caller status"
	Write-Host "PASS incompatible SDK fails before native build"

	Reset-BuildCase
	$global:WindowsBuildTestFailNative = $true
	$failed = $false
	try { & $scriptPath -Jobs 2 -VersionStatus beta1 } catch { $failed = $_.Exception.Message -match "Build of editor failed" }
	Assert-BuildCase $failed "native failure reported"
	Assert-BuildCase ($env:GODOT_VERSION_STATUS -eq "caller-status") "native failure restores caller status"
	Write-Host "PASS native failure restores version environment"

	Reset-BuildCase
	$global:WindowsBuildTestFailGlue = $true
	$failed = $false
	try { & $scriptPath -Mono -Jobs 2 -VersionStatus beta1 } catch { $failed = $_.Exception.Message -match "Generating the C# glue failed" }
	Assert-BuildCase $failed "glue failure reported"
	Assert-BuildCase (@($global:WindowsBuildTestCalls | Where-Object Kind -eq "python").Count -eq 1) "glue failure stops managed assembly build"
	Assert-BuildCase ($env:GODOT_VERSION_STATUS -eq "caller-status") "glue failure restores caller status"
	Write-Host "PASS glue failure stops managed build and restores version environment"
	Write-Host "All six build workflow cases passed. Windows native builds remain untested."
} finally {
	Set-Location $originalDirectory
	$env:GODOT_VERSION_STATUS = $originalStatus
	if ($originalPython) { Set-Item Function:\global:python $originalPython.ScriptBlock } else { Remove-Item Function:\global:python -ErrorAction SilentlyContinue }
	if ($originalDotnet) { Set-Item Function:\global:dotnet $originalDotnet.ScriptBlock } else { Remove-Item Function:\global:dotnet -ErrorAction SilentlyContinue }
	$global:WindowsBuildTestCalls = $previousCalls
	$global:WindowsBuildTestFailSdk = $previousFailSdk
	$global:WindowsBuildTestFailNative = $previousFailNative
	$global:WindowsBuildTestFailGlue = $previousFailGlue
	$global:LASTEXITCODE = $originalExitCode
	Remove-Item -Recurse -Force $fixture -ErrorAction SilentlyContinue
}
