# Self-test for the Windows runner. Run: powershell -NoProfile -File tests\smoke.ps1
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$runner = Join-Path $here '..\plugins\slow\scripts\slow.ps1'

$env:CODEX_HOME = Join-Path ([System.IO.Path]::GetTempPath()) ('slow-smoke-' + [guid]::NewGuid().ToString('N'))
$stateDir = Join-Path $env:CODEX_HOME 'slow'

$script:fails = 0

function Check {
    param([string]$Name, [string]$Expected, [string]$Actual)
    if ($Expected -eq $Actual) {
        Write-Output "ok   $Name"
    }
    else {
        Write-Output "FAIL $Name (expected [$Expected], got [$Actual])"
        $script:fails++
    }
}

function Invoke-Runner {
    param([string[]]$Arguments)
    & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $runner @Arguments
}

function Get-State {
    param([string]$Name)
    $path = Join-Path $stateDir $Name
    if (-not (Test-Path -LiteralPath $path)) { return '' }
    return (Get-Content -LiteralPath $path -Raw).Trim()
}

function Get-ReportedDelay {
    $line = (Invoke-Runner @('status') | Select-Object -First 1)
    if ($line -match '\(delay ([0-9.]+)s\)') { return $Matches[1] }
    return ''
}

Check 'fresh state reads as off' '0' (Get-ReportedDelay)

Invoke-Runner @('set', '3') | Out-Null
Check 'set 3 writes 3' '3' (Get-State 'delay')

Invoke-Runner @('set', '2m') | Out-Null
Check 'set 2m writes 120' '120' (Get-State 'delay')

Invoke-Runner @('set', '9999') | Out-Null
Check 'set 9999 clamps to 600' '600' (Get-State 'delay')

Invoke-Runner @('set', 'abc') | Out-Null
Check 'set abc is rejected' '1' "$LASTEXITCODE"
Check 'rejected value leaves state alone' '600' (Get-State 'delay')

Invoke-Runner @('off') | Out-Null
Check 'off writes 0' '0' (Get-State 'delay')
Check 'off keeps the last delay' '600' (Get-State 'last')

Invoke-Runner @('on') | Out-Null
Check 'on restores the last delay' '600' (Get-State 'delay')

Invoke-Runner @('set', '2') | Out-Null
$watch = [System.Diagnostics.Stopwatch]::StartNew()
Invoke-Runner @()
$watch.Stop()
$elapsed = $watch.Elapsed.TotalSeconds
if ($elapsed -ge 2 -and $elapsed -le 8) {
    Write-Output ("ok   tick sleeps ~2s (measured {0:N1}s)" -f $elapsed)
}
else {
    Write-Output ("FAIL tick slept {0:N1}s, expected about 2s" -f $elapsed)
    $script:fails++
}

Invoke-Runner @('off') | Out-Null
$watch = [System.Diagnostics.Stopwatch]::StartNew()
Invoke-Runner @()
$watch.Stop()
$elapsed = $watch.Elapsed.TotalSeconds
if ($elapsed -le 3) {
    Write-Output ("ok   tick returns quickly when off (measured {0:N1}s)" -f $elapsed)
}
else {
    Write-Output ("FAIL tick slept {0:N1}s while off" -f $elapsed)
    $script:fails++
}

$logLines = (Get-Content -LiteralPath (Join-Path $stateDir 'log') | Measure-Object -Line).Lines
Check 'log recorded the one real pause' '1' "$logLines"

if ($fails -eq 0) {
    Write-Output 'smoke.ps1: all checks passed'
}
else {
    Write-Output "smoke.ps1: $fails check(s) failed"
    exit 1
}
