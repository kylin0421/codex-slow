# Codex Slow

Manual slow mode for Codex. `$slow` makes the agent pause before every step, so
token usage burns more slowly and you get room to think — or to walk away —
while the session keeps working.

```
$slow           turn slow mode on (5 seconds by default)
$slow 10        ten seconds before every step
$slow 2m        two minutes before every step
$slow off       back to full speed
$slow status    what is it set to right now
```

`$slow` is the mention form Codex uses for skills: type `$`, pick **Slow** from
the list, then send. `/skills` opens the same picker, and plain language
("slow down", "take it slow") works too, because the skill description matches
it.

## Why not `/slow`?

Codex reserves the `/` menu for built-in commands. Skills can't register a slash
command there, so `/slow` answers `Unrecognized command '/slow'` and the input
never reaches the model. Checked directly against Codex CLI 0.155.0:

- `/slow`, a custom prompt (`/prompts:slow`), and a personal skill
  (`/cybergym`) all come back `Unrecognized command`.
- Typing `$slow` opens the skill picker and lists `slow (slow) [Skill]`.

So `$slow` (or `/skills`, or just asking in words) is the supported entry point.
No plugin can add a bare slash command; this is a Codex constraint, not a bug in
Slow.

## Install

One command. macOS / Linux:

```sh
curl -fsSL https://raw.githubusercontent.com/kylin0421/codex-slow/main/install.sh | sh
```

Windows (PowerShell):

```powershell
irm https://raw.githubusercontent.com/kylin0421/codex-slow/main/install.ps1 | iex
```

Then, once:

1. Run `/hooks` in Codex and trust the `slow` hook. Codex skips plugin hooks
   until you review and trust them.
2. Start a new session, type `$slow`, and send.

Prefer doing it by hand? The same two commands:

```sh
codex plugin marketplace add kylin0421/codex-slow
codex plugin add slow@codex-slow
```

## What it actually does

Slow ships two hooks that Codex loads alongside the plugin:

| Hook | Fires | Effect |
| --- | --- | --- |
| `UserPromptSubmit` | when you send a prompt | waits before the request goes out |
| `PreToolUse` | before every tool call | waits before the tool runs |

Both read a one-line setting and sleep for that many seconds. Codex waits for
the hook before continuing, so the pause lands between steps of the agent loop
rather than somewhere alongside it. One delay per tool call is what actually
paces a session: a turn with eight tool calls gets eight pauses.

## Settings

The delay lives in a plain text file with a single number in it:

| Platform | File |
| --- | --- |
| Windows | `%CODEX_HOME%\slow\delay`, or `%USERPROFILE%\.codex\slow\delay` |
| macOS / Linux | `$CODEX_HOME/slow/delay`, or `~/.codex/slow/delay` |

- Default: **5 seconds** — enough to feel the pause without fighting it.
- Maximum: **600 seconds** per pause.
- `0` means off. Deleting the file is also off.
- Editing the file by hand works exactly like using `/slow`.

Fine for your own taste: `1`–`3` is a light nudge, `10`–`30` is a real brake,
`60`+ is "check back later".

## Verify it is working

- `$slow status` prints the current delay and the timestamp of the last pause.
- Every pause is appended to `slow/log` next to the delay file, so you can see
  the loop being paced (the file is trimmed to the last 200 entries).
- `/hooks` lists the two hooks and whether they are trusted and enabled.

If you turn slow mode on and nothing is recorded, the hook is almost certainly
untrusted: run `/hooks` and trust it.

## Honest limitations

- **It paces the loop, not the token stream.** The model still generates a
  response at whatever speed the provider serves it; what changes is the
  spacing between user prompt → tool call → tool call → … A turn that makes no
  tool calls at all is only slowed by the `UserPromptSubmit` pause.
- **Trust is required once.** Untrusted plugin hooks are skipped silently.
- **It is global.** Slow mode applies to every Codex session on the machine
  until you turn it off; it is not per-chat.
- **It costs a little latency of its own.** On Windows each pause starts
  PowerShell (roughly 0.3–0.6 s of overhead) on top of the configured delay.
- **Hooks must be enabled.** They are on by default; `[features] hooks = false`
  in `config.toml` turns them off.
- **A pause can't exceed the hook timeout.** Delays are clamped to 600 s and
  the hook timeout is 900 s. If a hook is killed, Codex reports the failure and
  continues the tool call.
- **Slow is not a billing control.** It changes how fast work is requested, not
  what work costs.

## Uninstall

```sh
codex plugin remove slow@codex-slow
codex plugin marketplace remove codex-slow
```

The state directory (`<codex home>/slow/`) is yours; delete it if you don't
want to keep the last setting.

## Repository layout

```
.agents/plugins/marketplace.json     marketplace entry so Codex can install it
plugins/slow/.codex-plugin/plugin.json   plugin manifest
plugins/slow/hooks/hooks.json        the two lifecycle hooks
plugins/slow/scripts/slow.ps1        Windows runner (tick + on/off/set/status)
plugins/slow/scripts/slow.sh         macOS/Linux runner (same interface)
plugins/slow/skills/slow/SKILL.md    the /slow skill
tests/smoke.ps1, tests/smoke.sh      offline self-tests for both runners
```

## Development

The runners are dependency-free and can be tested without Codex:

```powershell
powershell -NoProfile -File tests\smoke.ps1
```

```sh
sh tests/smoke.sh
```

Both scripts point `CODEX_HOME` at a temporary directory, then check the
on/off/set/status contract and measure real pause durations.

## 中文快速开始

`$slow` 让 Codex 在每一步之间按你设定的秒数停顿，从而拉长 token 消耗的节奏，
也让你有更多时间思考或离开电脑。

安装（一条命令）：Windows 用 `irm .../install.ps1 | iex`，macOS/Linux 用
`curl .../install.sh | sh`。安装后先在 Codex 里运行 `/hooks` 信任 `slow`
钩子，然后新开会话输入 `$slow` 回车发送来开启（默认 5 秒），`$slow 10`
改成 10 秒，`$slow off` 关闭。

注意：Codex 的 `/` 菜单只放内建命令，技能无法注册斜杠命令，所以 `/slow`
会被拒绝为 `Unrecognized command`——必须用 `$slow`（或 `/skills` 里选）。

需要知道的一点：hook 只能给"每次工具调用/每次提问之前"加停顿，无法改变模型
自身输出 token 的流式速度。设置存放在 `<CODEX_HOME>/slow/delay`，直接编辑该
文件同样生效。

## License

MIT
