# Copilot instructions for claude-status

Build / test / lint
- No build, test, or lint toolchain in this repo (it's a small shell script project).
- Manual run: feed Claude Code session JSON to the script: cat session.json | ./statusline.sh or echo '{...}' | ./statusline.sh
- Install to Claude Code: ./install.sh (creates ~/.claude/statusline.sh and updates ~/.claude/settings.json)
- Uninstall: ./uninstall.sh
- Requirements: jq, git, standard coreutils (date supported either BSD or GNU). Ensure statusline.sh is executable (chmod +x).

High-level architecture
- Single-entry script: statusline.sh reads a Claude Code session JSON from stdin and emits a two-line ANSI statusline.
- One-pass parsing: jq extracts needed fields into a TSV which is read into shell variables in a single read to minimize passes over input.
- Presentation: helper functions (heat, meter, kfmt, clock_at, day_at) format colored meters, k-style numbers, and dates. Uses 256-color escapes and a conservative palette for non-truecolor hosts.
- Transcript aggregation: when a transcript JSONL path is present, the script uses jq to dedupe by message.id and sum output tokens to compute a session total.
- Installer: install.sh copies statusline.sh to ~/.claude/statusline.sh, makes a backup of settings.json, and sets statusLine to a command invoking the script.

Key conventions and patterns
- Single-pass jq + @tsv pattern: statusline.sh builds a JSON array in jq and outputs @tsv; the script uses IFS=$'\t' read -r ... < <(jq -r '[...] | @tsv' <<<"$json") to populate variables. Future edits should preserve this single-pass design for performance.
- Defensive defaults: variables are defaulted via parameter expansion (e.g., : "${model:=Claude}"). Empty or missing jq fields are normalized to "-" in the jq pipeline.
- Cross-platform date handling: clock_at/day_at attempt BSD (date -r) then fall back to GNU (date -d). Keep this ordering when modifying date code.
- Color helpers: functions c(), heat(), meter() centralize color and meter logic. Use them rather than embedding raw escape sequences.
- Transcript handling: transcript path is expected to be a file path; jq -rs + unique_by(.message.id) is used to compute session output tokens. Avoid re-reading transcript multiple times.
- Settings backup: install.sh saves previous settings.json to settings.json.bak-statusline and prints previous statusLine.command if present.

Files of interest
- statusline.sh — main implementation, ANSI output
- install.sh / uninstall.sh — installer and uninstaller
- README.md — usage, install notes, requirements

Other AI assistant configs
- No CLAUDE.md, AGENTS.md, .cursorrules, .windsurfrules, CONVENTIONS.md, or other known assistant config files were found.

MCP servers
- This repo is a small shell utility; no MCP servers appear necessary.

If you want adjustments (more detail on jq queries, sample JSON inputs for testing, or adding a small test harness), say what to include and it will be added.
