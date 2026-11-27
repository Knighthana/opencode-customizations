# Checks that the installed OpenCode Desktop loads this plugin, and with -Deep,
# that the app still exposes the GUI-plugin APIs it depends on.
#
#   powershell -File .\desktop\shared\plugins\net-proxy\verify.ps1 -Deep
#   pwsh        -File .\desktop\shared\plugins\net-proxy\verify.ps1 -Deep
#
# Exit code 0 = everything passed, 1 = something needs attention.
#
# Compatibility is decided by these structural checks, not by a version list:
# the entry needs the GUI plugin endpoint plus the ComposerPill and RPC APIs.
# Desktop and CLI versions are printed for diagnostics only.

[CmdletBinding()]
param(
  [switch]$Deep
)

$ErrorActionPreference = "Stop"

$compat = Join-Path $PSScriptRoot "_compat.ps1"

if (-not (Test-Path -LiteralPath $compat)) {
  throw "shared helper not found: $compat"
}

. $compat

$pluginDir = $PSScriptRoot
$files = @{
  "index.ts"             = Join-Path $pluginDir "index.ts"
  "rpc.ts"               = Join-Path $pluginDir "rpc.ts"
  "gui-experimental.cjs" = Join-Path $pluginDir "gui-experimental.cjs"
}
$guiFile = $files["gui-experimental.cjs"]
$configPath = Join-Path $HOME ".config\opencode\opencode.json"
$statePath = Join-Path $HOME ".config\opencode\net-proxy.json"
$desktopRoot = Join-Path $env:LOCALAPPDATA "Programs\ai.opencode.desktop"
$desktopExe = Join-Path $desktopRoot "OpenCode.exe"
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

    return Read-Utf8Text $stdout
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
      $text = Get-Latin1Text $buffer 0 $total

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
$desktopVersion = if (Test-Path -LiteralPath $desktopExe) {
  (Get-Item -LiteralPath $desktopExe).VersionInfo.ProductVersion
} else {
  "unknown"
}

if (Test-Path -LiteralPath $cli) {
  $version = (Invoke-NativeText $cli @("--version")).Trim()
  Add-Check "CLI reachable" ($version -match "opencode") $version
} else {
  Add-Check "CLI reachable" $false $cli
}

foreach ($entry in $files.GetEnumerator()) {
  Add-Check ("Plugin file present: {0}" -f $entry.Key) (Test-Path -LiteralPath $entry.Value) $entry.Value
}

Add-Check "Global config present" (Test-Path -LiteralPath $configPath) $configPath

$pluginPath = (Resolve-Path -LiteralPath $pluginDir).Path -replace "\\", "/"
$configured = $false

if (Test-Path -LiteralPath $configPath) {
  try {
    $config = ConvertFrom-JsonHashtable (Read-Utf8Text $configPath)
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
  # The background service can briefly miss a freshly added plugin (or be busy
  # right after a restart), so retry before reporting a failure.
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    $plugins = Invoke-NativeText $cli @("plugin", "list")
    if ($plugins -match "(?m)^\s*net-proxy\s") { break }
    Start-Sleep -Milliseconds 700
  }

  $listed = [bool]($plugins -match "(?m)^\s*net-proxy\s")
  $line = ($plugins -split "`n" | Where-Object { $_ -match "net-proxy" } | Select-Object -First 1)
  $package = if ($line) { $line.Trim() } else { "" }
}

Add-Check "Server lists net-proxy" $listed $package

$bundleOk = $false
$bundleDetail = ""

if ((Test-Path -LiteralPath $cli) -and (Test-Path -LiteralPath $guiFile)) {
  try {
    $raw = Invoke-NativeText $cli @("api", "get", "/api/plugin/gui?id=net-proxy")
    $response = $raw | ConvertFrom-Json
    $served = Normalize-Text $response.data.code
    $local = Normalize-Text (Read-Utf8Text $guiFile)
    $bundleOk = $served -eq $local
    $bundleDetail = if ($bundleOk) { "served bundle matches the local file" } else { "served bundle differs (restart/reload the app)" }
  } catch {
    $bundleDetail = $_.Exception.Message
  }
}

Add-Check "Server serves the current GUI bundle" $bundleOk $bundleDetail

$stateOk = $true
$stateDetail = "no state file yet (mode: auto)"

if (Test-Path -LiteralPath $statePath) {
  try {
    $state = ConvertFrom-JsonHashtable (Read-Utf8Text $statePath)
    $mode = [string]$state["mode"]
    $stateOk = $mode -in @("auto", "proxy", "direct")
    $stateDetail = if ($stateOk) { "mode: $mode" } else { "invalid mode: $mode" }
  } catch {
    $stateOk = $false
    $stateDetail = $_.Exception.Message
  }
}

Add-Check "Switch state is valid" $stateOk $stateDetail

if ($Deep) {
  if (Test-Path -LiteralPath $asar) {
    $markers = [ordered]@{
      "ComposerPill API"      = "ComposerPill"
      "plugin RPC module"     = "@opencode/plugin/rpc"
      "GUI plugin endpoint"   = "/api/plugin/gui"
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
Write-Host "OpenCode Desktop net-proxy verification"
Write-Host "--------------------------------------"
Write-Host ("Desktop {0} / CLI {1}" -f $desktopVersion, $version)
Write-Host ""

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
    Write-Host "All checks passed, including the app-internal API markers."
  }

  Write-Host "Compatibility is decided by these checks, not by a version list."
  exit 0
}

Write-Host "$($failed.Count) check(s) failed."
Write-Host "See README.md > Limits. After a Desktop update, the plugin may need"
Write-Host "small adjustments to the GUI/RPC API usage."
exit 1
