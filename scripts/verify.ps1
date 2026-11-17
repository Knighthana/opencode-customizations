# Checks that the installed OpenCode Desktop still loads this plugin, and with
# -Deep, that the app internals the plugin hooks into still exist.
#
#   pwsh -File .\scripts\verify.ps1
#   pwsh -File .\scripts\verify.ps1 -Deep
#
# Exit code 0 = everything passed, 1 = something needs attention.

[CmdletBinding()]
param(
  [switch]$Deep
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$pluginFile = Join-Path $repoRoot "enter-newline\gui-experimental.cjs"
$configPath = Join-Path $HOME ".config\opencode\opencode.json"
$desktopRoot = Join-Path $env:LOCALAPPDATA "Programs\ai.opencode.desktop"
$cli = Join-Path $desktopRoot "resources\opencode-cli.exe"
$asar = Join-Path $desktopRoot "resources\app.asar"

$checks = New-Object System.Collections.Generic.List[object]

function Add-Check([string]$Name, [bool]$Ok, [string]$Detail = "") {
  $checks.Add([pscustomobject]@{ Name = $Name; Ok = $Ok; Detail = $Detail })
}

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

function Normalize-Text([string]$value) {
  return ($value -replace "`r`n", "`n").TrimEnd("`n")
}

function Invoke-NativeText([string]$File, [string[]]$Arguments) {
  $stdout = [IO.Path]::GetTempFileName()
  $stderr = [IO.Path]::GetTempFileName()

  try {
    Start-Process -FilePath $File -ArgumentList $Arguments -NoNewWindow -Wait `
      -RedirectStandardOutput $stdout -RedirectStandardError $stderr | Out-Null

    return Get-Content -LiteralPath $stdout -Raw -Encoding utf8
  } finally {
    Remove-Item -LiteralPath $stdout, $stderr -Force -ErrorAction SilentlyContinue
  }
}

# Streams the file and looks for an ASCII marker, so a multi-hundred-MB
# app.asar never has to be loaded at once.
function Test-AsarPattern([string]$Path, [string]$Pattern) {
  $stream = [IO.File]::OpenRead($Path)
  $chunk = 8MB
  $overlap = [Math]::Max(256, $Pattern.Length * 4)
  $buffer = New-Object byte[] ($chunk + $overlap)
  $carry = 0

  try {
    while ($true) {
      $read = $stream.Read($buffer, $carry, $chunk)

      if ($read -le 0) { return $false }

      $total = $carry + $read
      $text = [Text.Encoding]::Latin1.GetString($buffer, 0, $total)

      if ($text.IndexOf($Pattern, [StringComparison]::Ordinal) -ge 0) { return $true }

      $carry = [Math]::Min($overlap, $total)
      [Array]::Copy($buffer, $total - $carry, $buffer, 0, $carry)
    }
  } finally {
    $stream.Dispose()
  }
}

$desktopOk = (Test-Path -LiteralPath $cli) -and (Test-Path -LiteralPath $asar)
Add-Check "OpenCode Desktop installed" $desktopOk $desktopRoot

$version = ""

if (Test-Path -LiteralPath $cli) {
  $version = (Invoke-NativeText $cli @("--version")).Trim()
  Add-Check "CLI reachable" ($version -match "opencode") $version
} else {
  Add-Check "CLI reachable" $false $cli
}

Add-Check "Plugin file present" (Test-Path -LiteralPath $pluginFile) $pluginFile
Add-Check "Global config present" (Test-Path -LiteralPath $configPath) $configPath

$pluginPath = (Resolve-Path -LiteralPath (Join-Path $repoRoot "enter-newline")).Path -replace "\\", "/"
$configured = $false

if (Test-Path -LiteralPath $configPath) {
  try {
    $config = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -AsHashtable
    $normalized = Normalize-PluginPath $pluginPath

    if ($config.Contains("plugins") -and $null -ne $config["plugins"]) {
      $configured = @($config["plugins"]) | Where-Object {
        (Normalize-PluginPath (Get-PackageEntry $_)) -eq $normalized
      } | ForEach-Object { $true } | Select-Object -First 1
    }
  } catch {
    Add-Check "Global config parses as JSON" $false $_.Exception.Message
  }
}

Add-Check "Config points at this plugin" ([bool]$configured) $pluginPath

$listed = $false
$package = ""

if (Test-Path -LiteralPath $cli) {
  $plugins = Invoke-NativeText $cli @("plugin", "list")
  $listed = [bool]($plugins -match "(?m)^\s*enter-newline\s")
  $line = ($plugins -split "`n" | Where-Object { $_ -match "enter-newline" } | Select-Object -First 1)
  $package = if ($line) { $line.Trim() } else { "" }
}

Add-Check "Server lists enter-newline" $listed $package

$bundleOk = $false
$bundleDetail = ""

if ((Test-Path -LiteralPath $cli) -and (Test-Path -LiteralPath $pluginFile)) {
  try {
    $raw = Invoke-NativeText $cli @("api", "get", "/api/plugin/gui?id=enter-newline")
    $response = $raw | ConvertFrom-Json
    $served = Normalize-Text $response.data.code
    $local = Normalize-Text (Get-Content -LiteralPath $pluginFile -Raw)
    $bundleOk = $served -eq $local
    $bundleDetail = if ($bundleOk) { "served bundle matches the local file" } else { "served bundle differs (restart/reload the app)" }
  } catch {
    $bundleDetail = $_.Exception.Message
  }
}

Add-Check "Server serves the current GUI bundle" $bundleOk $bundleDetail

if ($Deep) {
  if (Test-Path -LiteralPath $asar) {
    $markers = [ordered]@{
      "composer-editor marker"    = "composer-editor"
      "composer form marker"      = 'data-component="composer"'
      "suggestion popover marker" = "data-suggestion-id"
      "line-break API marker"     = "insertLineBreak"
    }

    foreach ($entry in $markers.GetEnumerator()) {
      $found = Test-AsarPattern $asar $entry.Value
      Add-Check "App still has $($entry.Key)" $found $entry.Value
    }
  } else {
    Add-Check "App.asar readable" $false $asar
  }
}

Write-Host ""
Write-Host "OpenCode Desktop plugin verification"
Write-Host "------------------------------------"

foreach ($check in $checks) {
  $mark = if ($check.Ok) { "PASS" } else { "FAIL" }
  Write-Host ("[{0}] {1}" -f $mark, $check.Name)

  if ($check.Detail) { Write-Host ("       {0}" -f $check.Detail) }
}

$failed = @($checks | Where-Object { -not $_.Ok })

Write-Host ""

if ($failed.Count -eq 0) {
  if (-not $Deep) {
    Write-Host "All checks passed. Run with -Deep after an OpenCode Desktop update."
  } else {
    Write-Host "All checks passed, including the app-internal markers."
  }

  exit 0
}

Write-Host "$($failed.Count) check(s) failed."
Write-Host "See README.md > Troubleshooting. After a Desktop update, the plugin may need"
Write-Host "small adjustments to the app-internal selectors."
exit 1
