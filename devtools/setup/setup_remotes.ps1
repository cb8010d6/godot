# Configure local remotes without fetching or pushing. Existing URLs are kept;
# a recognizable non-reference GitHub origin becomes fork on a fresh clone.
param([string]$Repository = (Resolve-Path "$PSScriptRoot\..\..").Path)
$ErrorActionPreference = "Stop"

function Invoke-RemoteGit([string[]]$Arguments) {
	$output = @(& git -C $Repository @Arguments)
	if ($LASTEXITCODE -ne 0) { throw "Local git remote configuration failed." }
	return $output
}

function Get-GitHubRepository([string]$Url) {
	$path = $null
	if ($Url -match "^(?:[^/@:]+@)?(?:github\.com|ssh\.github\.com):(?<repository>[^?#]+)$") {
		$path = $Matches.repository
	} else {
		$uri = $null
		if ([uri]::TryCreate($Url, [UriKind]::Absolute, [ref]$uri) -and
			$uri.Scheme -in @("http", "https", "ssh", "git") -and
			$uri.Host -in @("github.com", "ssh.github.com", "www.github.com")) {
			$path = $uri.AbsolutePath
		}
	}
	if (-not $path) { return $null }
	$path = $path.Trim("/") -replace "\.git$", ""
	if ($path -notmatch "^[\w.-]+/[\w.-]+$") { return $null }
	return $path.ToLowerInvariant()
}

$references = @("godotengine/godot", "nvidia-rtx/godot", "uno1982/godot", "diginaat/godot")
$sources = [ordered]@{
	"upstream" = "https://github.com/godotengine/godot.git"
	"origin" = "https://github.com/NVIDIA-RTX/godot.git"
	"physx" = "https://github.com/uno1982/godot.git"
}
$remotes = @(Invoke-RemoteGit @("remote"))
if (($remotes -contains "origin") -and ($remotes -notcontains "fork")) {
	$originUrls = @(Invoke-RemoteGit @("remote", "get-url", "--all", "origin"))
	$identity = if ($originUrls.Count -eq 1) { Get-GitHubRepository $originUrls[0] } else { $null }
	# Diginaat is an integration source, but an existing clone keeps that exact
	# URL under fork. Its push guard below still applies.
	if ($identity -and (($references -notcontains $identity) -or $identity -eq "diginaat/godot")) {
		Invoke-RemoteGit @("remote", "rename", "origin", "fork") | Out-Null
		Write-Host "Renamed existing GitHub origin to fork; its URL is unchanged."
		$remotes = @(Invoke-RemoteGit @("remote"))
	}
}
foreach ($name in $sources.Keys) {
	if ($remotes -notcontains $name) {
		Invoke-RemoteGit @("remote", "add", $name, $sources[$name]) | Out-Null
		Write-Host "Added reference remote $name."
	}
}
$remotes = @(Invoke-RemoteGit @("remote"))
foreach ($name in $remotes) {
	$fetchUrls = @(Invoke-RemoteGit @("remote", "get-url", "--all", $name))
	$pushUrls = @(Invoke-RemoteGit @("remote", "get-url", "--push", "--all", $name))
	$reference = @($fetchUrls + $pushUrls | Where-Object { $references -contains (Get-GitHubRepository $_) }).Count -gt 0
	if ($reference) {
		if ($pushUrls.Count -ne 1 -or $pushUrls[0] -cne "DISABLED") {
			Invoke-RemoteGit @("config", "--replace-all", "remote.$name.pushurl", "DISABLED") | Out-Null
		}
		Write-Host "Push disabled for reference destination on remote $name."
	}
}
if ($remotes -notcontains "fork") {
	Write-Host "No fork detected. Add your personal fork explicitly: git remote add fork <your-fork-url>"
} else {
	$forkUrls = @(Invoke-RemoteGit @("remote", "get-url", "--all", "fork"))
	if (@($forkUrls | Where-Object { $references -contains (Get-GitHubRepository $_) }).Count) {
		Write-Host "fork points to a reference repository; pushes are disabled. Select your personal fork explicitly before publishing."
	}
}
