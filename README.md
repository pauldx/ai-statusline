# ai-statusline

Portable two-line status lines for [Claude Code](https://claude.com/claude-code) and
[GitHub Copilot CLI](https://docs.github.com/copilot/how-tos/copilot-cli).

```
🤖 Fable 5 │ 🧠 ██░░░░░░ 25%  ↑50k  ↓1.2k  Σ↓5.1k │ 💰 $1.3625 │ 📁 myrepo  ⎇ main │ ✚61  ✖0
⚡ 5h █░░░░░░░ 16%  ⟳ 7:20am     📅 7d ░░░░░░░░ 8%  ⟳ jul 20
```

## What it shows

**Line 1** — `🤖` model name · `🧠` context-window meter + % (green→yellow→red), `↑` input
tokens (incl. cache), `↓` output tokens this turn, `Σ↓` session output total (summed from
the transcript JSONL, deduped by message id) · `💰` session cost (when reported) · `📁` cwd
basename · `⎇` git branch + `✎` dirty flag · `✚/✖` lines added/removed.

**Line 2** — `⚡` 5-hour rate-limit meter + % + reset time · `📅` 7-day meter + % + reset date.

## Install

```bash
git clone https://github.com/pauldx/ai-statusline.git
cd ai-statusline
./install.sh        # copies script to ~/.claude/, wires settings.json (backs it up first)
```

For GitHub Copilot CLI:

```bash
./install-copilot.sh  # copies statusline.sh to ~/.copilot/ and wires settings.json (backs it up first)
```

Auto-detection: statusline.sh now detects whether incoming JSON is from Copilot or Claude and delegates to copilot-statusline.sh when appropriate. Detection heuristics look for `.workspace`, `.allow_all_enabled`, or a `model.id` matching /copilot/i. This lets a single installed command handle both Claude Code and Copilot CLI.

Copilot-specific features: copilot-statusline.sh shows AI usage, elapsed session time, remote status, and the `YOLO` allow-all indicator. Use `install-copilot.sh` to wire the Copilot-specific installer; the main `install.sh` continues to install the Claude variant.

## Requirements

- [jq](https://jqlang.github.io/jq/) — for parsing JSON
- git — for branch info

On macOS:

```bash
brew install jq
```

Works on macOS + Linux (`date` handled for both).

## Uninstall

```bash
./uninstall.sh      # removes statusLine key + ~/.claude/statusline.sh
./uninstall-copilot.sh  # removes statusLine key + ~/.copilot/statusline.sh
```

## How it's wired

The installer sets in `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash \"$HOME/.claude/statusline.sh\""
  }
}
```

Claude Code pipes session JSON to the command on every render; the script parses it with
`jq` in a single pass and prints 256-color ANSI lines. An existing custom `statusLine` is
backed up to `settings.json.bak-statusline` and its previous command printed during install.

Copilot CLI uses the same command-on-stdin pattern. Its installer updates
`~/.copilot/settings.json` (or `$COPILOT_HOME/settings.json`) and saves the previous file as
`settings.json.bak-statusline`.

## License

MIT — see LICENSE.
