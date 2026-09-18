---
name: slow
description: Turn Codex's manual slow mode on, off, or to a specific delay, and report its status. Use whenever the user asks to slow Codex down, pace or stretch out token usage, pause between steps, take a breather, or types /slow or $slow.
---

# Slow

Slow mode inserts a configurable pause before every tool call and before every
user prompt. It exists so a session burns tokens more slowly and so the human
keeps room to think — or to walk away — while the work continues.

The pause is enforced by the `PreToolUse` and `UserPromptSubmit` hooks this
plugin installs. This skill only edits the setting the hook reads; it must not
try to simulate slowness itself.

## Runner

Locate this skill's own directory (Codex reports the path when it loads the
skill). The plugin root is two levels up: `<plugin root>/skills/slow` →
`<plugin root>`.

Then use the runner for the host platform:

- Windows:
  `powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "<plugin root>\scripts\slow.ps1" <args>`
- macOS / Linux:
  `sh "<plugin root>/scripts/slow.sh" <args>`

## Map the request to one call

| User intent | Args |
| --- | --- |
| `/slow`, "slow down", "take it slow" | `on` |
| `/slow off`, "stop slowing", "full speed" | `off` |
| `/slow 10`, `/slow 10s`, `/slow 2m`, "wait 10s per step" | `set 10` |
| `/slow status`, "is slow mode on?" | `status` |

Default delay is 5 seconds when the user has never set one. Maximum is 600
seconds. `set 0` is equivalent to `off`.

## Reply

Relay the runner's output as-is, then add at most two short lines if they apply:

- If the user just turned slow mode on and no pause is being recorded, tell them
  to run `/hooks` once and trust the `slow` hook; untrusted hooks are skipped.
- Otherwise remind them that `/slow off` turns it back off.

Do not add commentary about token counts, billing, or the model's speed beyond
what the runner printed, and do not run the runner more than once per request.
