<#
.SYNOPSIS
    Flip the proxy switch read by the net-proxy OpenCode plugin.

.DESCRIPTION
    Writes %USERPROFILE%\.config\opencode\net-proxy.json (or
    $XDG_CONFIG_HOME/opencode). The plugin polls that file once per second and
    applies the change to the already-running server: no restart, no daemon, no
    port, no environment variables outside that server process.

    The plugin itself is the half that does the work; this script only edits the
    switch state.

.PARAMETER Command
    on        force HTTP(S)_PROXY to the upstream
    off       remove them (direct)
    auto      stop managing; restore what the server inherited
    upstream  change the upstream URL
    status    print the current switch state

.PARAMETER Value
    Upstream URL for the upstream command.
#>
[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [ValidateSet('on', 'off', 'auto', 'upstream', 'status')]
    [string]$Command = 'status',

    [Parameter(Position = 1)]
    [string]$Value
)

$ErrorActionPreference = 'Stop'

$configHome = if ($env:XDG_CONFIG_HOME) { $env:XDG_CONFIG_HOME } else { Join-Path $HOME '.config' }
$configDir = Join-Path $configHome 'opencode'
$statePath = Join-Path $configDir 'net-proxy.json'
$defaultUpstream = 'http://127.0.0.1:7897'

New-Item -ItemType Directory -Force -Path $configDir | Out-Null

function Read-State {
    if (-not (Test-Path -LiteralPath $statePath)) {
        return [pscustomobject]@{ mode = 'auto'; upstream = $defaultUpstream }
    }

    try {
        $parsed = Get-Content -LiteralPath $statePath -Raw | ConvertFrom-Json
    }
    catch {
        throw "Cannot parse ${statePath}: $($_.Exception.Message)"
    }

    $mode = if ($parsed.mode -in 'auto', 'proxy', 'direct') { $parsed.mode } else { 'auto' }
    $upstream = if ($parsed.upstream) { [string]$parsed.upstream } else { $defaultUpstream }
    return [pscustomobject]@{ mode = $mode; upstream = $upstream }
}

function Write-State {
    param([string]$Mode, [string]$Upstream)

    $json = [ordered]@{ mode = $Mode; upstream = $Upstream } | ConvertTo-Json
    $temp = "$statePath.tmp"
    Set-Content -LiteralPath $temp -Value $json -Encoding ASCII
    Move-Item -LiteralPath $temp -Destination $statePath -Force
}

$state = Read-State

switch ($Command) {
    'on' {
        Write-State -Mode 'proxy' -Upstream $state.upstream
        Write-Host "net-proxy: proxy -> $($state.upstream)"
    }
    'off' {
        Write-State -Mode 'direct' -Upstream $state.upstream
        Write-Host 'net-proxy: direct'
    }
    'auto' {
        Write-State -Mode 'auto' -Upstream $state.upstream
        Write-Host 'net-proxy: auto (not managing)'
    }
    'upstream' {
        if (-not $Value) { throw 'Usage: net-proxy.ps1 upstream http://127.0.0.1:7897' }
        $uri = $null
        if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'http') {
            throw "Upstream must be an http:// URL, got: $Value"
        }
        Write-State -Mode $state.mode -Upstream $Value.Trim()
        Write-Host "net-proxy: upstream -> $($Value.Trim()) (mode: $($state.mode))"
    }
    default {
        Write-Host "mode    : $($state.mode)"
        Write-Host "upstream: $($state.upstream)"
        Write-Host "state   : $statePath"
    }
}
