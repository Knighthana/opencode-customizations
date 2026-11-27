<#
.SYNOPSIS
    Register (or unregister) the net-proxy plugin in the global OpenCode config.

.DESCRIPTION
    Adds this directory to the `plugins` array in
    %USERPROFILE%\.config\opencode\opencode.json, keeping every other entry.
    The first change backs the original file up to opencode.json.bak.

    The plugin itself lives beside this script and is referenced by its absolute
    path, so editing index.ts needs no reinstall.

    Works with Windows PowerShell 5.1 and PowerShell 7+.

.PARAMETER Uninstall
    Remove the entry instead of adding it.

.PARAMETER ConfigDir
    Global config directory. Defaults to %USERPROFILE%\.config\opencode.
    Mostly useful for testing the installer itself.
#>
[CmdletBinding()]
param(
    [switch]$Uninstall,
    [string]$ConfigDir
)

$ErrorActionPreference = 'Stop'

$pluginDir = ((Resolve-Path -LiteralPath $PSScriptRoot).Path -replace '\\', '/').TrimEnd('/')
$configDir = if ($ConfigDir) { $ConfigDir } else { Join-Path $HOME '.config\opencode' }
$configPath = Join-Path $configDir 'opencode.json'
$jsoncPath = Join-Path $configDir 'opencode.jsonc'
$backupPath = Join-Path $configDir 'opencode.json.bak'
$schema = 'https://opencode.ai/config.json'

if (Test-Path -LiteralPath $jsoncPath) {
    throw @"
Found $jsoncPath.
This installer only edits opencode.json and an opencode.jsonc may take precedence.
Add this entry to the `plugins` array there by hand:

  "$pluginDir"

"@
}

New-Item -ItemType Directory -Force -Path $configDir | Out-Null

function Normalize([string]$value) {
    if (-not $value) { return '' }
    return (($value -replace '\\', '/').TrimEnd('/')).ToLowerInvariant()
}

function Get-EntryPath([object]$entry) {
    if ($entry -is [string]) { return $entry }
    if ($entry -and $entry.PSObject.Properties.Name -contains 'package') { return [string]$entry.package }
    return $null
}

if (Test-Path -LiteralPath $configPath) {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json
    if (-not (Test-Path -LiteralPath $backupPath)) {
        Copy-Item -LiteralPath $configPath -Destination $backupPath
    }
}
else {
    $config = [pscustomobject]@{ '$schema' = $schema }
}

$plugins = @()
if ($config.PSObject.Properties.Name -contains 'plugins') {
    $plugins = @($config.plugins)
}

$target = Normalize $pluginDir
$kept = @($plugins | Where-Object { (Normalize (Get-EntryPath $_)) -ne $target })

if ($Uninstall) {
    $next = $kept
}
else {
    $next = @($kept) + $pluginDir
}

if ($config.PSObject.Properties.Name -contains 'plugins') {
    $config.plugins = $next
}
else {
    $config | Add-Member -NotePropertyName plugins -NotePropertyValue $next
}

$json = $config | ConvertTo-Json -Depth 20
[IO.File]::WriteAllText($configPath, $json, (New-Object Text.UTF8Encoding($false)))

if ($Uninstall) {
    Write-Host "net-proxy: removed from $configPath"
}
else {
    Write-Host "net-proxy: registered in $configPath"
    Write-Host "restart OpenCode Desktop (or run the reload command) to load the plugin."
}
