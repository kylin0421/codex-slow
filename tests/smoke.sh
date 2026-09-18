#!/bin/sh
# Self-test for the POSIX runner. Run: sh tests/smoke.sh
set -u

here=$(cd "$(dirname "$0")" && pwd)
runner=$here/../plugins/slow/scripts/slow.sh
work=$(mktemp -d 2>/dev/null || mktemp -d -t slow)
CODEX_HOME=$work
export CODEX_HOME

fails=0

check() {
	if [ "$2" = "$3" ]; then
		printf 'ok   %s\n' "$1"
	else
		printf 'FAIL %s (expected [%s], got [%s])\n' "$1" "$2" "$3"
		fails=$((fails + 1))
	fi
}

delay() {
	cat "$CODEX_HOME/slow/delay" 2>/dev/null
}

last() {
	cat "$CODEX_HOME/slow/last" 2>/dev/null
}

check "fresh state reads as off" "0" "$(sh "$runner" status | head -1 | sed -n 's/.*(delay \([0-9.]*\)s).*/\1/p')"

sh "$runner" set 3 >/dev/null
check "set 3 writes 3" "3" "$(delay)"

sh "$runner" set 2m >/dev/null
check "set 2m writes 120" "120" "$(delay)"

sh "$runner" set 9999 >/dev/null
check "set 9999 clamps to 600" "600" "$(delay)"

sh "$runner" set abc >/dev/null 2>&1
check "set abc is rejected" "1" "$?"
check "rejected value leaves state alone" "600" "$(delay)"

sh "$runner" off >/dev/null
check "off writes 0" "0" "$(delay)"
check "off keeps the last delay" "600" "$(last)"

sh "$runner" on >/dev/null
check "on restores the last delay" "600" "$(delay)"

sh "$runner" set 2 >/dev/null
start=$(date +%s)
sh "$runner"
end=$(date +%s)
elapsed=$((end - start))
if [ "$elapsed" -ge 2 ] && [ "$elapsed" -le 6 ]; then
	printf 'ok   tick sleeps ~2s (measured %ss)\n' "$elapsed"
else
	printf 'FAIL tick slept %ss, expected about 2s\n' "$elapsed"
	fails=$((fails + 1))
fi

sh "$runner" off >/dev/null
start=$(date +%s)
sh "$runner"
end=$(date +%s)
elapsed=$((end - start))
if [ "$elapsed" -le 1 ]; then
	printf 'ok   tick returns immediately when off (measured %ss)\n' "$elapsed"
else
	printf 'FAIL tick slept %ss while off\n' "$elapsed"
	fails=$((fails + 1))
fi

check "log recorded the one real pause" "1" "$(wc -l <"$CODEX_HOME/slow/log" | tr -d ' ')"

if [ "$fails" = "0" ]; then
	echo "smoke.sh: all checks passed"
else
	echo "smoke.sh: $fails check(s) failed"
	exit 1
fi
