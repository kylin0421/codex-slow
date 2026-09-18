# Codex Slow - one-command install for Windows.
# Usage: irm https://raw.githubusercontent.com/kylin0421/codex-slow/main/install.ps1 | iex
$ErrorActionPreference = 'Stop'

$repo = if ($env:CODEX_SLOW_REPO) { $env:CODEX_SLOW_REPO } else { 'kylin0421/codex-slow' }

if (-not (Get-Command codex -ErrorAction SilentlyContinue)) {
    Write-Error 'codex CLI not found on PATH. Install Codex first: https://developers.openai.com/codex'
}

Write-Output "Adding marketplace $repo"
try {
    & codex plugin marketplace add $repo
}
catch {
    Write-Output 'note: marketplace add reported an error (already added?) - continuing'
}

Write-Output 'Installing plugin slow'
& codex plugin add 'slow@codex-slow'

Write-Output ''
Write-Output 'Installed.'
Write-Output ''
Write-Output 'Next:'
Write-Output '  1. Run /hooks once and trust the slow hook (plugin hooks are skipped until trusted).'
Write-Output '  2. In a new session, run /slow to turn slow mode on, /slow 10 for ten seconds, /slow off to stop.'
