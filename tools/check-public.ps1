# Scans tracked files for content that does not belong in a public repository:
# references to private/audit repositories, absolute user paths, and secrets.
#
#   powershell -File .\tools\check-public.ps1
#   pwsh        -File .\tools\check-public.ps1
#
# Works on Windows PowerShell 5.1 and PowerShell 7+. Exit code 0 means clean.
# The patterns are written as \uXXXX escapes so this file stays ASCII and the
# Chinese terms match even when Windows PowerShell 5.1 reads it as ANSI.

[CmdletBinding()]
param(
  [string]$Root
)

$ErrorActionPreference = "Stop"

$root = if ($Root) { (Resolve-Path -LiteralPath $Root).Path } else { Split-Path -Parent $PSScriptRoot }

$rules = @(
  @{
    Name    = "private-repo reference"
    Pattern = '(\u79c1\u6709\u4ed3\u5e93|\u672c\u5730\u79c1\u6709|\u672c\u673a OpenCode|\u6539\u52a8\u5ba1\u8ba1|\u4e0d\u63a8\u5230\u8fdc\u7a0b|\u4e2a\u4eba\u673a\u5668\u7684\u914d\u7f6e|\u8e29\u5751\u8bb0\u5f55)'
  },
  @{
    Name    = "absolute user path"
    Pattern = '[A-Za-z]:\\Users\\[^\\\s"'']+'
  },
  @{
    Name    = "credential"
    Pattern = '(gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|sk-[A-Za-z0-9]{20,})'
  }
)

function Get-RepositoryFiles([string]$Path) {
  $git = Get-Command git -ErrorAction SilentlyContinue

  if ($git) {
    $listed = & git -C $Path ls-files 2>$null

    if ($LASTEXITCODE -eq 0 -and $listed) {
      return @($listed)
    }
  }

  # `-Name` yields paths relative to $Path, which avoids mixing 8.3 and long
  # path prefixes when TEMP or the repository lives under a short name.
  return @(
    Get-ChildItem -LiteralPath $Path -Recurse -File -Force -Name |
      Where-Object { $_ -notmatch "^\.git([\\/]|$)" }
  )
}

$findings = New-Object System.Collections.Generic.List[object]
$scanned = 0

foreach ($relative in Get-RepositoryFiles $root) {
  $relative = $relative -replace "/", [IO.Path]::DirectorySeparatorChar
  $file = Join-Path $root $relative

  if (-not (Test-Path -LiteralPath $file)) { continue }

  $bytes = [IO.File]::ReadAllBytes($file)

  # Skip binaries: a public-source repo has no reason to embed secrets in them,
  # and decoding them as text only produces noise.
  if ([Array]::IndexOf($bytes, [byte]0) -ge 0) { continue }

  $scanned++
  $text = [Text.Encoding]::UTF8.GetString($bytes)
  $lines = [regex]::Split($text, "\r?\n")

  for ($i = 0; $i -lt $lines.Length; $i++) {
    foreach ($rule in $rules) {
      if ($lines[$i] -match $rule.Pattern) {
        $findings.Add([pscustomobject]@{
            File    = $relative
            Line    = $i + 1
            Rule    = $rule.Name
            Content = $lines[$i].Trim()
          })
      }
    }
  }
}

Write-Host ""
Write-Host "Public-repository scan"
Write-Host "---------------------"

if ($findings.Count -eq 0) {
  Write-Host ("Scanned {0} text files; no findings." -f $scanned) -ForegroundColor Green
  exit 0
}

foreach ($finding in $findings) {
  Write-Host ("{0}:{1}: [{2}] {3}" -f $finding.File, $finding.Line, $finding.Rule, $finding.Content) -ForegroundColor Red
}

Write-Host ""
Write-Host ("{0} finding(s) in {1} scanned files." -f $findings.Count, $scanned)
Write-Host "Remove private context from public docs; keep personal notes outside this repo."
exit 1
