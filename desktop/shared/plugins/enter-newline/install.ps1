# Installs (or uninstalls) the Enter-newline GUI plugin in the global
# OpenCode Desktop configuration.
#
#   powershell -File .\desktop\shared\plugins\enter-newline\install.ps1
#   pwsh        -File .\desktop\shared\plugins\enter-newline\install.ps1
#
# Both the Windows PowerShell 5.1 that ships with Windows and PowerShell 7+
# work. The plugin lives beside this script and is referenced by its absolute
# path, so editing it here needs no reinstall.

[CmdletBinding()]
param(
  [switch]$Uninstall
)

$ErrorActionPreference = "Stop"

$compat = Join-Path $PSScriptRoot "_compat.ps1"

if (-not (Test-Path -LiteralPath $compat)) {
  throw "shared helper not found: $compat"
}

. $compat

$pluginDir = $PSScriptRoot
$pluginFile = Join-Path $pluginDir "gui-experimental.cjs"
$configDir = Join-Path $HOME ".config\opencode"
$configPath = Join-Path $configDir "opencode.json"
$jsoncPath = Join-Path $configDir "opencode.jsonc"
$schemaUrl = "https://opencode.ai/config.json"

function Normalize-PluginPath([string]$value) {
  if (-not $value) { return "" }

  return (($value -replace "\\", "/").TrimEnd("/")).ToLowerInvariant()
}

function Get-PackageEntry([object]$entry) {
  if ($entry -is [string]) { return $entry }

  if ($entry -is [System.Collections.IDictionary] -and $entry.Contains("package")) {
    return [string]$entry["package"]
  }

  return $null
}

if (-not $Uninstall -and -not (Test-Path -LiteralPath $pluginFile)) {
  throw "plugin file not found: $pluginFile"
}

if (Test-Path -LiteralPath $jsoncPath) {
  throw @"
Found $jsoncPath.
This installer only edits opencode.json, and an existing opencode.jsonc may take
precedence. Add this entry to the `plugins` array in that file by hand:

  "$((Resolve-Path -LiteralPath $pluginDir).Path -replace '\\', '/')"

Then re-run this installer (powershell or pwsh both work):
  powershell -File "$PSCommandPath"
"@
}

$pluginPath = (Resolve-Path -LiteralPath $pluginDir).Path -replace "\\", "/"
$normalizedPlugin = Normalize-PluginPath $pluginPath

New-Item -ItemType Directory -Force -Path $configDir | Out-Null

$config = $null

if (Test-Path -LiteralPath $configPath) {
  $raw = Read-Utf8Text $configPath

  try {
    $config = ConvertFrom-JsonHashtable $raw
  } catch {
    throw "Could not parse $configPath as JSON. Add this path to `plugins` by hand instead: $pluginPath"
  }

  $backup = "$configPath.bak"
  Copy-Item -LiteralPath $configPath -Destination $backup -Force
  Write-Host "Backed up existing config to $backup"
}

if ($null -eq $config) {
  $config = [ordered]@{}
}

if (-not $config.Contains('$schema')) {
  $config['$schema'] = $schemaUrl
}

$existing = @()

if ($config.Contains("plugins") -and $null -ne $config["plugins"]) {
  $existing = @($config["plugins"])
}

$kept = @(
  $existing | Where-Object {
    $value = Get-PackageEntry $_

    if ($null -eq $value) { return $true }

    return (Normalize-PluginPath $value) -ne $normalizedPlugin
  }
)

if ($Uninstall) {
  $config["plugins"] = $kept
  Write-Host "Removed from $configPath :"
  Write-Host "  $pluginPath"
} else {
  $config["plugins"] = @($kept + @($pluginPath))
  Write-Host "Added to $configPath :"
  Write-Host "  $pluginPath"
}

$json = $config | ConvertTo-Json -Depth 100
Write-Utf8Text $configPath $json

Write-Host ""
Write-Host "Current plugins:"
if (@($config["plugins"]).Count -eq 0) {
  Write-Host "  (none)"
} else {
  @($config["plugins"]) | ForEach-Object { Write-Host "  $(Get-PackageEntry $_)" }
}

$missing = @(
  @($config["plugins"]) | Where-Object {
    $value = Get-PackageEntry $_

    if ($null -eq $value) { return $false }
    if ($value -notmatch "[\\/]" -and $value -notmatch "^\.") { return $false }

    return -not (Test-Path -LiteralPath $value)
  }
)

if ($missing.Count -gt 0) {
  Write-Host ""
  Write-Host "Warning: these plugin entries point at missing directories:" -ForegroundColor Yellow

  $missing | ForEach-Object { Write-Host "  $(Get-PackageEntry $_)" -ForegroundColor Yellow }

  Write-Host "Remove stale entries with -Uninstall after restoring the path, or edit $configPath." -ForegroundColor Yellow
}

Write-Host ""

if ($Uninstall) {
  Write-Host "Restart OpenCode Desktop to unload the plugin."
  exit 0
}

Write-Host "Next steps:"
Write-Host "  1. Reload the Desktop window (Ctrl+R), or restart OpenCode Desktop."
Write-Host "  2. Run: powershell -File `"$PSScriptRoot\verify.ps1`" -Deep"
Write-Host "     (PowerShell 7 users can substitute pwsh.)"
Write-Host ""
Write-Host "Expected behaviour in the prompt composer:"
Write-Host "  Enter            newline"
Write-Host "  Shift+Enter      newline"
Write-Host "  Ctrl+Enter       send (Cmd+Enter on macOS)"
Write-Host ""
Write-Host "The plugin appears under Settings > Shortcuts (section: prompt) and"
Write-Host "Settings > Extensions > Plugins."
