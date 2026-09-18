#!/bin/sh
# Codex Slow - one-command install for macOS and Linux.
# Usage: curl -fsSL https://raw.githubusercontent.com/kylin0421/codex-slow/main/install.sh | sh
set -u

repo=${CODEX_SLOW_REPO:-kylin0421/codex-slow}

if ! command -v codex >/dev/null 2>&1; then
	echo "codex CLI not found on PATH. Install Codex first: https://developers.openai.com/codex" >&2
	exit 1
fi

echo "Adding marketplace $repo"
codex plugin marketplace add "$repo" || echo "note: marketplace add reported an error (already added?) - continuing"

echo "Installing plugin slow"
codex plugin add "slow@codex-slow"

cat <<'EOF'

Installed.

Next:
  1. Run /hooks once and trust the slow hook (plugin hooks are skipped until trusted).
  2. In a new session, type $slow and send to turn slow mode on, $slow 10 for ten
     seconds, $slow off to stop. Codex skills are $ mentions, not slash commands.
EOF
