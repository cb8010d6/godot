# Runs the actual remote setup against isolated local Git repositories.
# Requires Git and Windows PowerShell 5.1 or PowerShell 7. Never fetches/pushes.
$ErrorActionPreference = "Stop"
$sourceRoot = (Resolve-Path "$PSScriptRoot\..\..").Path
$setupScript = Join-Path $sourceRoot "devtools\setup\setup_remotes.ps1"
$fixture = Join-Path $sourceRoot "devtools\out\windows-remotes-$([guid]::NewGuid().ToString('N'))"
$originalGlobalConfig = $env:GIT_CONFIG_GLOBAL
$originalNoSystem = $env:GIT_CONFIG_NOSYSTEM
$originalExitCode = $global:LASTEXITCODE

function Invoke-FixtureGit([string]$Repository, [string[]]$Arguments) {
	$output = @(& git -C $Repository @Arguments)
	if ($LASTEXITCODE -ne 0) { throw "Fixture Git command failed: $Arguments" }
	return $output
}

function Assert-RemoteCase([bool]$Condition, [string]$Message) {
	if (-not $Condition) { throw "Assertion failed: $Message" }
}

function New-RemoteCase([string]$Name) {
	$repository = Join-Path $fixture $Name
	New-Item -ItemType Directory -Force $repository | Out-Null
	Invoke-FixtureGit $repository @("init", "--quiet") | Out-Null
	return $repository
}

function Assert-Url([string]$Repository, [string]$Remote, [string]$Url, [switch]$Push) {
	$arguments = @("remote", "get-url")
	if ($Push) { $arguments += "--push" }
	$arguments += @("--all", $Remote)
	$actual = @(Invoke-FixtureGit $Repository $arguments)
	Assert-RemoteCase ($actual.Count -eq 1 -and $actual[0] -ceq $Url) "$Remote URL preserved/guarded ($Url)"
}

function Assert-References([string]$Repository) {
	Assert-Url $Repository "origin" "https://github.com/NVIDIA-RTX/godot.git"
	Assert-Url $Repository "upstream" "https://github.com/godotengine/godot.git"
	Assert-Url $Repository "physx" "https://github.com/uno1982/godot.git"
	foreach ($name in @("origin", "upstream", "physx")) { Assert-Url $Repository $name "DISABLED" -Push }
}

function Assert-Idempotent([string]$Repository) {
	$before = [IO.File]::ReadAllText((Join-Path $Repository ".git\config"))
	& $setupScript -Repository $Repository
	$after = [IO.File]::ReadAllText((Join-Path $Repository ".git\config"))
	Assert-RemoteCase ($before -ceq $after) "second setup does not change configuration"
}

try {
	New-Item -ItemType Directory -Force $fixture | Out-Null
	$env:GIT_CONFIG_GLOBAL = Join-Path $fixture "empty-gitconfig"
	[IO.File]::WriteAllText($env:GIT_CONFIG_GLOBAL, "")
	$env:GIT_CONFIG_NOSYSTEM = "1"

	foreach ($url in @("https://github.com/example-user/godot.git", "git@github.com:Example-User/Godot.git", "ssh://git@github.com:443/example-user/godot.git")) {
		$repository = New-RemoteCase ([guid]::NewGuid().ToString("N"))
		Invoke-FixtureGit $repository @("remote", "add", "origin", $url) | Out-Null
		Invoke-FixtureGit $repository @("config", "branch.work.remote", "origin") | Out-Null
		& $setupScript -Repository $repository
		Assert-Url $repository "fork" $url
		Assert-Url $repository "fork" $url -Push
		Assert-RemoteCase ((Invoke-FixtureGit $repository @("config", "branch.work.remote")) -ceq "fork") "rename updates branch tracking"
		Assert-References $repository
		Assert-Idempotent $repository
	}
	Write-Host "PASS personal HTTPS, SCP SSH and SSH URL clones retain exact fork URL and tracking"

	$repository = New-RemoteCase "diginaat"
	$url = "https://GitHub.com/Diginaat/Godot.git"
	Invoke-FixtureGit $repository @("remote", "add", "origin", $url) | Out-Null
	& $setupScript -Repository $repository
	Assert-Url $repository "fork" $url
	Assert-Url $repository "fork" "DISABLED" -Push
	Assert-References $repository
	Assert-Idempotent $repository
	Write-Host "PASS Diginaat clone is retained as fork and protected from pushes"

	$repository = New-RemoteCase "existing-custom"
	$custom = [ordered]@{ origin = "https://example.invalid/custom/nvidia.git"; upstream = "https://example.invalid/custom/godot.git"; physx = "ssh://git@example.invalid/physx.git"; fork = "git@github.com:example-user/godot.git" }
	foreach ($name in $custom.Keys) { Invoke-FixtureGit $repository @("remote", "add", $name, $custom[$name]) | Out-Null }
	Invoke-FixtureGit $repository @("remote", "set-url", "--push", "fork", "ssh://git@github.com/example-push/godot.git") | Out-Null
	& $setupScript -Repository $repository
	foreach ($name in $custom.Keys) { Assert-Url $repository $name $custom[$name] }
	Assert-Url $repository "fork" "ssh://git@github.com/example-push/godot.git" -Push
	Assert-Idempotent $repository
	Write-Host "PASS existing fork and custom reference URLs are not overwritten"

	$repository = New-RemoteCase "unknown-origin"
	$url = "https://example.invalid/some/godot.git"
	Invoke-FixtureGit $repository @("remote", "add", "origin", $url) | Out-Null
	& $setupScript -Repository $repository
	Assert-Url $repository "origin" $url
	Assert-Url $repository "origin" $url -Push
	Assert-RemoteCase (@(Invoke-FixtureGit $repository @("remote")) -notcontains "fork") "unknown origin does not guess a fork"
	Assert-Idempotent $repository
	Write-Host "PASS unknown origin is preserved without a guessed fork"

	$repository = New-RemoteCase "reference-origin"
	Invoke-FixtureGit $repository @("remote", "add", "origin", "https://github.com/NVIDIA-RTX/godot.git") | Out-Null
	& $setupScript -Repository $repository
	Assert-References $repository
	Assert-RemoteCase (@(Invoke-FixtureGit $repository @("remote")) -notcontains "fork") "reference clone does not guess a fork"
	Assert-Idempotent $repository
	Write-Host "PASS NVIDIA clone remains origin without a guessed fork"

	$repository = New-RemoteCase "no-remotes"
	& $setupScript -Repository $repository
	Assert-References $repository
	Assert-RemoteCase (@(Invoke-FixtureGit $repository @("remote")) -notcontains "fork") "repository without remotes does not guess a fork"
	Assert-Idempotent $repository
	Write-Host "PASS repository without remotes gets only protected reference remotes"

	$repository = New-RemoteCase "ambiguous-origin"
	Invoke-FixtureGit $repository @("remote", "add", "origin", "https://github.com/example-one/godot.git") | Out-Null
	Invoke-FixtureGit $repository @("remote", "set-url", "--add", "origin", "https://github.com/example-two/godot.git") | Out-Null
	& $setupScript -Repository $repository
	$urls = @(Invoke-FixtureGit $repository @("remote", "get-url", "--all", "origin"))
	Assert-RemoteCase ($urls.Count -eq 2 -and $urls[0] -ceq "https://github.com/example-one/godot.git" -and $urls[1] -ceq "https://github.com/example-two/godot.git") "multiple fetch URLs preserved"
	Assert-RemoteCase (@(Invoke-FixtureGit $repository @("remote")) -notcontains "fork") "ambiguous origin does not guess a fork"
	Assert-Idempotent $repository
	Write-Host "PASS multiple origin URLs are preserved without guessing"

	$repository = New-RemoteCase "reference-push-guard"
	Invoke-FixtureGit $repository @("remote", "add", "fork", "https://github.com/example-user/godot.git") | Out-Null
	Invoke-FixtureGit $repository @("remote", "set-url", "--push", "fork", "https://github.com/example-push/godot.git") | Out-Null
	Invoke-FixtureGit $repository @("remote", "set-url", "--push", "--add", "fork", "ssh://git@ssh.github.com:443/NVIDIA-RTX/Godot.git") | Out-Null
	Invoke-FixtureGit $repository @("remote", "add", "odd-name", "git@github.com:GodotEngine/Godot.GIT") | Out-Null
	Invoke-FixtureGit $repository @("remote", "set-url", "--push", "odd-name", "https://github.com/example-push/godot.git") | Out-Null
	& $setupScript -Repository $repository
	Assert-Url $repository "fork" "https://github.com/example-user/godot.git"
	Assert-Url $repository "fork" "DISABLED" -Push
	Assert-Url $repository "odd-name" "git@github.com:GodotEngine/Godot.GIT"
	Assert-Url $repository "odd-name" "DISABLED" -Push
	Assert-References $repository
	Assert-Idempotent $repository
	Write-Host "PASS reference fetch or any effective push destination is guarded regardless of remote name"

	Write-Host "PASS 8 remote setup cases (10 repositories), each checked for idempotency"
} finally {
	$env:GIT_CONFIG_GLOBAL = $originalGlobalConfig
	$env:GIT_CONFIG_NOSYSTEM = $originalNoSystem
	$global:LASTEXITCODE = $originalExitCode
	if (Test-Path $fixture) { Remove-Item -Recurse -Force $fixture }
}
