# Codex Slow - pacing helper (Windows).
#
#   slow.ps1              tick mode: sleep for the configured delay, print nothing
#   slow.ps1 on           enable slow mode (reuse the last configured delay)
#   slow.ps1 off          disable slow mode (keeps the last delay for later)
#   slow.ps1 set <value>  set the delay: 5, 5s, 2m, or 0 to disable
#   slow.ps1 status       print the current state
#
# The configured delay lives in <codex-home>\slow\delay, so the hook and this
# script always agree and the file can also be edited by hand.

[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Command = 'tick',
    [Parameter(Position = 1)][string]$Value = ''
)

$ErrorActionPreference = 'SilentlyContinue'
$DefaultDelay = 5
$MaxDelay = 600

$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$stateDir = Join-Path $codexHome 'slow'
$delayFile = Join-Path $stateDir 'delay'
$lastFile = Join-Path $stateDir 'last'
$logFile = Join-Path $stateDir 'log'

function Read-Number {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $raw = Get-Content -LiteralPath $Path -Raw
    if ($null -eq $raw) { return '' }
    $raw = $raw.Trim()
    if ($raw -notmatch '^[0-9]+(\.[0-9]+)?$') { return '' }
    return $raw
}

function Get-Normalized {
    param([string]$Raw)
    $parsed = 0.0
    if (-not [double]::TryParse($Raw, [ref]$parsed)) { return '0' }
    if ($parsed -lt 0) { $parsed = 0 }
    if ($parsed -gt $MaxDelay) { $parsed = $MaxDelay }
    return ('' + [double]$parsed)
}

function Test-Positive {
    param([string]$Raw)
    $parsed = 0.0
    if (-not [double]::TryParse($Raw, [ref]$parsed)) { return $false }
    return ($parsed -gt 0)
}

function Get-CurrentDelay {
    $value = Read-Number $delayFile
    if (-not $value) { return '0' }
    return $value
}

function Get-LastDelay {
    $value = Read-Number $lastFile
    if (-not $value) { return ('' + $DefaultDelay) }
    return $value
}

function ConvertTo-Seconds {
    param([string]$Raw)
    $text = $Raw.Trim()
    $multiplier = 1
    if ($text -match '(?i)^(.+?)m$') { $multiplier = 60; $text = $Matches[1] }
    elseif ($text -match '(?i)^(.+?)s$') { $multiplier = 1; $text = $Matches[1] }
    $number = 0.0
    if (-not [double]::TryParse($text, [ref]$number)) { return $null }
    return ('' + ($number * $multiplier))
}

function Write-State {
    param([string]$Path, [string]$Text)
    if (-not (Test-Path -LiteralPath $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
    Set-Content -LiteralPath $Path -Value $Text -Encoding ascii
}

function Get-LastTick {
    if (-not (Test-Path -LiteralPath $logFile)) { return '' }
    $line = Get-Content -LiteralPath $logFile -Tail 1
    return $line
}

function Write-StateReport {
    $delay = Get-Normalized (Get-CurrentDelay)
    $state = if (Test-Positive $delay) { 'ON' } else { 'OFF' }
    Write-Output "slow mode: $state (delay ${delay}s)"
    Write-Output "pauses: before every tool call and every user prompt"
    Write-Output "settings file: $delayFile"
    Write-Output "default: ${DefaultDelay}s, maximum: ${MaxDelay}s, 0 turns it off"
    $tick = Get-LastTick
    if ($tick) { Write-Output "last pause: $tick" } else { Write-Output "last pause: none recorded yet" }
}

switch ($Command.ToLowerInvariant()) {
    'tick' {
        $raw = Read-Number $delayFile
        if (-not $raw) { exit 0 }
        $delay = Get-Normalized $raw
        if (-not (Test-Positive $delay)) { exit 0 }
        if (-not (Test-Path -LiteralPath $stateDir)) { New-Item -ItemType Directory -Path $stateDir -Force | Out-Null }
        $stamp = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        Add-Content -LiteralPath $logFile -Value "$stamp`t$delay"
        if (Test-Path -LiteralPath $logFile) {
            Get-Content -LiteralPath $logFile -Tail 200 | Set-Content -LiteralPath $logFile -Encoding ascii
        }
        Start-Sleep -Seconds ([double]$delay)
        exit 0
    }
    'on' {
        $delay = Get-Normalized (Get-LastDelay)
        if (-not (Test-Positive $delay)) { $delay = '' + $DefaultDelay }
        Write-State -Path $delayFile -Text $delay
        Write-State -Path $lastFile -Text $delay
        Write-StateReport
    }
    'off' {
        Write-State -Path $delayFile -Text '0'
        Write-StateReport
    }
    'stop' {
        Write-State -Path $delayFile -Text '0'
        Write-StateReport
    }
    'set' {
        if (-not $Value) {
            Write-Output 'usage: slow.ps1 set <seconds|Ns|Nm>'
            exit 1
        }
        $seconds = ConvertTo-Seconds $Value
        if ($null -eq $seconds) {
            Write-Output "not a delay: $Value (try 5, 5s, 2m, or 0 to turn slow mode off)"
            exit 1
        }
        $delay = Get-Normalized $seconds
        Write-State -Path $delayFile -Text $delay
        if (Test-Positive $delay) { Write-State -Path $lastFile -Text $delay }
        Write-StateReport
    }
    'status' {
        Write-StateReport
    }
    default {
        Write-Output 'usage: slow.ps1 [tick|on|off|set <value>|status]'
        exit 1
    }
}
