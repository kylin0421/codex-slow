#!/bin/sh
# Codex Slow - pacing helper (POSIX).
#
#   slow.sh              tick mode: sleep for the configured delay, print nothing
#   slow.sh on           enable slow mode (reuse the last configured delay)
#   slow.sh off          disable slow mode (keeps the last delay for later)
#   slow.sh set <value>  set the delay: 5, 5s, 2m, or 0 to disable
#   slow.sh status       print the current state
#
# The configured delay lives in <codex-home>/slow/delay, so the hook and this
# script always agree and the file can also be edited by hand.

set -u

DEFAULT_DELAY=5
MAX_DELAY=600

codex_home=${CODEX_HOME:-$HOME/.codex}
state_dir=$codex_home/slow
delay_file=$state_dir/delay
last_file=$state_dir/last
log_file=$state_dir/log

read_number() {
	# Echo the validated numeric content of a state file, or nothing.
	[ -f "$1" ] || return 0
	value=$(tr -dc '0-9.' <"$1" 2>/dev/null)
	case "$value" in
	'' | .* | *. | *.*.*) return 0 ;;
	esac
	printf '%s' "$value"
}

current_delay() {
	value=$(read_number "$delay_file")
	printf '%s' "${value:-0}"
}

last_delay() {
	value=$(read_number "$last_file")
	printf '%s' "${value:-$DEFAULT_DELAY}"
}

# Clamp to 0..MAX_DELAY and drop trailing noise like 5.0 -> 5.
normalize() {
	awk -v v="$1" -v m="$MAX_DELAY" 'BEGIN { if (v < 0) v = 0; if (v > m) v = m; printf "%g", v }'
}

is_positive() {
	[ "$(awk -v v="$1" 'BEGIN { print (v > 0) ? 1 : 0 }')" = "1" ]
}

parse_seconds() {
	# Accept 5, 5s, 5S, 2m, 2M and whitespace.
	raw=$(printf '%s' "$1" | tr -d ' ')
	case "$raw" in
	*m | *M)
		mult=60
		num=${raw%?}
		;;
	*s | *S)
		mult=1
		num=${raw%?}
		;;
	*)
		mult=1
		num=$raw
		;;
	esac
	case "$num" in
	'' | .* | *. | *.*.* | *[!0-9.]*) return 1 ;;
	esac
	awk -v n="$num" -v m="$mult" 'BEGIN { printf "%g", n * m }'
}

write_delay() {
	mkdir -p "$state_dir" 2>/dev/null
	printf '%s\n' "$1" >"$delay_file" 2>/dev/null
}

write_last() {
	mkdir -p "$state_dir" 2>/dev/null
	printf '%s\n' "$1" >"$last_file" 2>/dev/null
}

last_tick() {
	[ -f "$log_file" ] || return 0
	tail -n 1 "$log_file" 2>/dev/null
}

print_state() {
	delay=$(normalize "$(current_delay)")
	if is_positive "$delay"; then
		state=ON
	else
		state=OFF
	fi
	echo "slow mode: $state (delay ${delay}s)"
	echo "pauses: before every tool call and every user prompt"
	echo "settings file: $delay_file"
	echo "default: ${DEFAULT_DELAY}s, maximum: ${MAX_DELAY}s, 0 turns it off"
	tick=$(last_tick)
	if [ -n "$tick" ]; then
		echo "last pause: $tick"
	else
		echo "last pause: none recorded yet"
	fi
}

do_tick() {
	raw=$(read_number "$delay_file")
	[ -n "$raw" ] || exit 0
	delay=$(normalize "$raw")
	is_positive "$delay" || exit 0

	mkdir -p "$state_dir" 2>/dev/null
	stamp=$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)
	printf '%s at %ss\n' "${stamp:-?}" "$delay" >>"$log_file" 2>/dev/null
	if [ -f "$log_file" ]; then
		tail -n 200 "$log_file" >"$log_file.tmp" 2>/dev/null &&
			mv "$log_file.tmp" "$log_file" 2>/dev/null
	fi

	sleep "$delay" 2>/dev/null
	exit 0
}

command=${1:-tick}

case "$command" in
tick)
	do_tick
	;;
on)
	delay=$(normalize "$(last_delay)")
	is_positive "$delay" || delay=$DEFAULT_DELAY
	write_delay "$delay"
	write_last "$delay"
	print_state
	;;
off | stop)
	write_delay 0
	print_state
	;;
set)
	if [ $# -lt 2 ]; then
		echo "usage: slow.sh set <seconds|Ns|Nm>"
		exit 1
	fi
	if ! value=$(parse_seconds "$2"); then
		echo "not a delay: $2 (try 5, 5s, 2m, or 0 to turn slow mode off)"
		exit 1
	fi
	value=$(normalize "$value")
	write_delay "$value"
	if is_positive "$value"; then
		write_last "$value"
	fi
	print_state
	;;
status)
	print_state
	;;
*)
	echo "usage: slow.sh [tick|on|off|set <value>|status]"
	exit 1
	;;
esac
