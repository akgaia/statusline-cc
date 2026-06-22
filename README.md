# statusline-cc

A clean, single-line status line for [Claude Code](https://claude.com/claude-code).
**Calm by default — color only shows up when something needs your attention.**

```
statusline-cc │ main ~2 │ Opus 4.8 │ 5h:12% │ 7d:8% │ ctx:34% │ ↓45k │ ↑12k │ cache:230k │ New 3:45pm
```

It shows, left to right:

| Field        | Meaning                                                                 |
| ------------ | ----------------------------------------------------------------------- |
| `folder`     | Current project folder                                                  |
| `main ~2`    | Git branch, with `+N` staged and `~N` modified file counts              |
| `Opus 4.8`   | Active model (the `Claude` prefix and context suffix are stripped)      |
| `5h:12%`     | Percentage of the 5-hour rate-limit window used                         |
| `7d:8%`      | Percentage of the 7-day rate-limit window used                          |
| `ctx:34%`    | Context window used — the anchor field, bold green/yellow/red           |
| `↓45k`       | Session-cumulative input tokens                                         |
| `↑12k`       | Session-cumulative output tokens                                        |
| `cache:230k` | Cache-read input tokens                                                 |
| `New 3:45pm` | Local time the 5-hour rate-limit window resets                          |

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

Works on macOS and Linux (date formatting handles both).

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
