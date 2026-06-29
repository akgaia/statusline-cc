# statusline-cc

A clean, single-line status line for [Claude Code](https://claude.com/claude-code).
**Calm by default — color only shows up when something needs your attention.**

```
statusline-cc │ main ~2 │ Opus 4.8 xhigh │ 5h:12% (3:45p) │ 7d:8% │ ctx:34% │ ↓8k │ ↑1k │ cache:64k
```

It shows, left to right:

| Field        | Meaning                                                                 |
| ------------ | ----------------------------------------------------------------------- |
| `folder`     | Current project folder                                                  |
| `main ~2`    | Git branch, with `+N` staged and `~N` modified file counts              |
| `Opus 4.8 xhigh` | Active model (the `Claude` prefix and context suffix are stripped), followed by the reasoning effort (`low`/`medium`/`high`/`xhigh`/`max`) when the model supports it |
| `5h:12% (3:45p)` | Percentage of the 5-hour rate-limit window used, with the local time the window resets in parens |
| `7d:8%`      | Percentage of the 7-day rate-limit window used                          |
| `ctx:34%`    | Context window used — the anchor field, bold green/yellow/red           |
| `↓8k`        | New (uncached) input tokens in the current turn                         |
| `↑1k`        | Output tokens generated in the current turn                             |
| `cache:64k`  | Input tokens served from cache in the current turn                      |

### Color = attention needed

Most fields are dim. They light up as thresholds are crossed, so a glance tells you whether anything matters:

- **`ctx`** (context window) — bold **green** under 70%, **yellow** at 70%+, bold **red** at 90%+.
- **`5h`** rate limit — bold **green** under 60%, bold **yellow** at 60%+, bold **red** at 80%+.
- **`7d`** rate limit — dim under 60%, **yellow** at 60%+, bold **red** at 80%+.
- **Git** — branch in cyan, staged in cyan, modified in yellow.

## Requirements

- **bash**
- **node** — used for fast, robust JSON parsing of the payload Claude Code passes in
- **git** — optional; the git field simply hides itself outside a repo

### Platform support

Portable bash + coreutils, with both GNU (`date -d @epoch`) and BSD
(`date -r epoch`) date paths, so it behaves the same everywhere bash runs:

| Platform | Status |
| --- | --- |
| **macOS** | ✅ Works (BSD `date`) |
| **Linux** | ✅ Works (GNU `date`) |
| **Windows — WSL** | ✅ Works — behaves like Linux |
| **Windows — Git Bash** | ✅ Works — Claude Code runs the status line through Git Bash, which bundles bash, GNU coreutils, and `node` |
| **Windows — no Git Bash (PowerShell)** | ❌ Not supported — POSIX tools are unavailable; this would need a PowerShell port |

> Line endings are pinned to LF via [`.gitattributes`](.gitattributes) so a
> CRLF checkout on Windows can't break the `#!/bin/bash` shebang.

## Install

### Quick install

```sh
git clone https://github.com/akgaia/statusline-cc.git
cd statusline-cc
./install.sh
```

The installer copies `statusline.sh` to `~/.claude/`, makes it executable, and merges the
`statusLine` setting into `~/.claude/settings.json` (backing the file up first). It never
overwrites your other settings. Restart Claude Code and the status line appears.

### Manual install

1. Copy the script and make it executable:

   ```sh
   cp statusline.sh ~/.claude/statusline.sh
   chmod +x ~/.claude/statusline.sh
   ```

2. Add this to `~/.claude/settings.json`:

   ```json
   {
     "statusLine": {
       "type": "command",
       "command": "~/.claude/statusline.sh"
     }
   }
   ```

3. Restart Claude Code (or start a new session).

> If you set `CLAUDE_CONFIG_DIR`, use that directory instead of `~/.claude`.

## Customize

The script is plain bash — edit `~/.claude/statusline.sh` directly.

- **Thresholds** — tweak the numbers in the `thresh_color "$VALUE" WARN CRIT` calls (e.g. `CTX_COLOR=$(thresh_color_important "$CTX_PCT" 70 90)`).
- **Fields & order** — the final block builds `OUT` field by field; comment out or reorder lines to taste.
- **Separator** — change `SEP=" ${DIM}│${RST} "`.
- **Colors** — the ANSI codes are defined together near the top.

## Debugging

Run with `STATUSLINE_DEBUG=1` to dump the raw JSON payload Claude Code sends to
`/tmp/claude-statusline-last-payload.json` — handy when adding new fields:

```sh
echo '{}' | STATUSLINE_DEBUG=1 ~/.claude/statusline.sh
cat /tmp/claude-statusline-last-payload.json
```

node parse errors (if any) are written to `/tmp/claude-statusline-node-err.log`.

## License

MIT — see [LICENSE](LICENSE).
