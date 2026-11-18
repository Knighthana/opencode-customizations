# Runs the plugin's behaviour tests in a headless Chromium browser.
#
#   powershell -File .\desktop\shared\plugins\enter-newline\tests\test.ps1
#   pwsh        -File .\desktop\shared\plugins\enter-newline\tests\test.ps1
#
# Requires Chrome or Edge. Exit code 0 = all tests passed. Works on Windows
# PowerShell 5.1 and PowerShell 7+.

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$pluginDir = Split-Path -Parent $PSScriptRoot
$compat = Join-Path $pluginDir "_compat.ps1"

if (-not (Test-Path -LiteralPath $compat)) {
  throw "shared helper not found: $compat"
}

. $compat

$pluginFile = Join-Path $pluginDir "gui-experimental.cjs"
$harness = Join-Path $PSScriptRoot "harness.html"

$browsers = @(
  (Join-Path $env:ProgramFiles "Google\Chrome\Application\chrome.exe"),
  (Join-Path ${env:ProgramFiles(x86)} "Google\Chrome\Application\chrome.exe"),
  (Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe"),
  (Join-Path $env:ProgramFiles "Microsoft\Edge\Application\msedge.exe"),
  (Join-Path ${env:ProgramFiles(x86)} "Microsoft\Edge\Application\msedge.exe")
)

$browser = $browsers | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -First 1

if (-not $browser) {
  throw "Chrome or Edge not found. Install one, or open tests\harness.html in a browser after replacing /*__PLUGIN_SOURCE__*/ with the plugin."
}

if (-not (Test-Path -LiteralPath $pluginFile)) {
  throw "plugin file not found: $pluginFile"
}

$source = Read-Utf8Text $pluginFile
$page = Read-Utf8Text $harness

if ($page -notmatch [regex]::Escape("/*__PLUGIN_SOURCE__*/")) {
  throw "tests\harness.html is missing the /*__PLUGIN_SOURCE__*/ marker"
}

$page = $page.Replace("/*__PLUGIN_SOURCE__*/", $source)
$temp = Join-Path ([IO.Path]::GetTempPath()) ("enter-newline-test-{0}.html" -f [guid]::NewGuid())
$profile = Join-Path ([IO.Path]::GetTempPath()) ("enter-newline-profile-{0}" -f [guid]::NewGuid())
$stdout = Join-Path ([IO.Path]::GetTempPath()) ("enter-newline-out-{0}.txt" -f [guid]::NewGuid())
$stderr = Join-Path ([IO.Path]::GetTempPath()) ("enter-newline-err-{0}.txt" -f [guid]::NewGuid())

Write-Utf8Text $temp $page

try {
  $uri = "file:///" + ($temp -replace "\\", "/")
  $process = Start-Process -FilePath $browser -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdout `
    -RedirectStandardError $stderr -ArgumentList @(
      "--headless=new",
      "--disable-gpu",
      "--no-first-run",
      "--no-default-browser-check",
      "--user-data-dir=$profile",
      "--dump-dom",
      $uri
    )

  $dom = Read-Utf8Text $stdout
} finally {
  Remove-Item -LiteralPath $temp, $stdout, $stderr -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath $profile -Recurse -Force -ErrorAction SilentlyContinue
}

if (-not $dom) {
  Write-Host "The browser produced no output (exit code $($process.ExitCode))." -ForegroundColor Red
  exit 1
}

$match = [regex]::Match($dom, '(?s)<pre id="results">(.*?)</pre>')

if (-not $match.Success) {
  Write-Host "Could not read test results from the browser output." -ForegroundColor Red
  exit 1
}

$results = [System.Net.WebUtility]::HtmlDecode($match.Groups[1].Value).Trim()

Write-Host $results
Write-Host ""

$failures = @($results -split "`n" | Where-Object { $_ -match "^FAIL" })

if ($failures.Count -gt 0 -or $results -match "(?m)^pending$") {
  Write-Host "$($failures.Count) test(s) failed." -ForegroundColor Red
  exit 1
}

Write-Host "All plugin tests passed." -ForegroundColor Green
exit 0
