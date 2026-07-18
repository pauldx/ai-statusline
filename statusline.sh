#!/usr/bin/env bash
# claude-status — two-line statusline for Claude Code.
#
# Claude Code pipes session JSON on stdin; this prints:
#   line 1: model │ context meter │ ↑in ↓out Σ↓session │ cost │ dir ⎇ branch │ ✚/✖
#   line 2: ⚡ 5-hour and 📅 7-day rate-limit meters with reset times
set -u
set -f

json=$(cat 2>/dev/null || true)
if [ -z "$json" ]; then
    printf '🤖 Claude'
    exit 0
fi

# ── Palette (256-color: some statusline hosts ignore truecolor) ──────────
ESC=$'\033'
R="${ESC}[0m" B="${ESC}[1m" D="${ESC}[2m"
c() { printf '%s[38;5;%sm' "$ESC" "$1"; }
C_MODEL=$(c 33) C_IN=$(c 37) C_OUT=$(c 135) C_COST=$(c 136)
C_DIR=$(c 37) C_GIT=$(c 35) C_HOT=$(c 160) C_OK=$(c 35) C_TIME=$(c 102)
SEP=" ${D}│${R} "

heat() {  # heat <pct> → color escalating with load
    local p=$1
    if   [ "$p" -ge 90 ]; then c 160
    elif [ "$p" -ge 70 ]; then c 178
    elif [ "$p" -ge 50 ]; then c 208
    else                       c 35
    fi
}

meter() {  # meter <pct> [width] → colored block gauge
    local p=$1 w=${2:-8}
    [ "$p" -lt 0 ] 2>/dev/null && p=0
    [ "$p" -gt 100 ] 2>/dev/null && p=100
    local on=$(( p * w / 100 ))
    local solid='████████████████' faint='░░░░░░░░░░░░░░░░'
    printf '%s%s%s%s%s' "$(heat "$p")" "${solid:0:on}" "$D" "${faint:0:w-on}" "$R"
}

kfmt() {  # 12345 → 12.3k, 2000 → 2k, 950 → 950
    awk -v n="${1:-0}" 'BEGIN {
        if (n >= 1000) { v = n / 1000; printf((v == int(v)) ? "%dk" : "%.1fk", v) }
        else printf("%d", n)
    }'
}

clock_at() {  # epoch → "7:20am" (BSD date first, GNU fallback)
    local e=$1
    case "$e" in ''|-|null) return ;; esac
    { date -r "$e" '+%l:%M%p' 2>/dev/null || date -d "@$e" '+%l:%M%P' 2>/dev/null; } \
        | awk '{ gsub(/^ +|\./, ""); print tolower($0) }'
}

day_at() {  # epoch → "jul 20"
    local e=$1
    case "$e" in ''|-|null) return ;; esac
    { date -r "$e" '+%b %e' 2>/dev/null || date -d "@$e" '+%b %-d' 2>/dev/null; } \
        | awk '{ sub(/  +/, " "); print tolower($0) }'
}

# ── One-pass field extraction (empty → "-" so TSV fields survive read) ───
IFS=$'\t' read -r model ctx_max tok_in tok_cw tok_cr tok_out cost adds dels \
    cwd transcript pct5 at5 pct7 at7 < <(
    jq -r '[
        (.model.display_name // "Claude"),
        (.context_window.context_window_size // 200000),
        (.context_window.current_usage.input_tokens // 0),
        (.context_window.current_usage.cache_creation_input_tokens // 0),
        (.context_window.current_usage.cache_read_input_tokens // 0),
        (.context_window.current_usage.output_tokens // 0),
        (.cost.total_cost_usd // "-"),
        (.cost.total_lines_added // 0),
        (.cost.total_lines_removed // 0),
        (.cwd // "-"),
        (.transcript_path // "-"),
        (.rate_limits.five_hour.used_percentage // "-"),
        (.rate_limits.five_hour.resets_at // "-"),
        (.rate_limits.seven_day.used_percentage // "-"),
        (.rate_limits.seven_day.resets_at // "-")
    ] | map(if . == "" then "-" else . end) | @tsv' <<<"$json" 2>/dev/null
) || true

: "${model:=Claude}" "${ctx_max:=200000}" "${tok_in:=0}" "${tok_cw:=0}" "${tok_cr:=0}"
: "${tok_out:=0}" "${cost:=-}" "${adds:=0}" "${dels:=0}" "${cwd:=-}"
: "${transcript:=-}" "${pct5:=-}" "${at5:=-}" "${pct7:=-}" "${at7:=-}"

# ── Session-total output tokens: transcript JSONL, one row per message id ─
sess_out=0
if [ "$transcript" != "-" ] && [ -f "$transcript" ]; then
    sess_out=$(jq -rs '
        [ .[] | select(.message.usage.output_tokens != null) ]
        | unique_by(.message.id)
        | map(.message.usage.output_tokens) | add // 0
    ' "$transcript" 2>/dev/null || echo 0)
fi

# ── Context load ─────────────────────────────────────────────────────────
[ "$ctx_max" -le 0 ] 2>/dev/null && ctx_max=200000
ctx_used=$(( tok_in + tok_cw + tok_cr ))
ctx_pct=$(( ctx_used * 100 / ctx_max ))

# ── Git state ────────────────────────────────────────────────────────────
[ "$cwd" = "-" ] && cwd=$PWD
folder=${cwd##*/}
branch=$(git -C "$cwd" branch --show-current 2>/dev/null || true)
edited=''
if [ -n "$branch" ] && [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
    edited=" ${C_HOT}✎${R}"
fi

# ── Line 1 ───────────────────────────────────────────────────────────────
load=$(heat "$ctx_pct")
L1="${B}${C_MODEL}🤖 ${model}${R}"
L1+="${SEP}🧠 $(meter "$ctx_pct") ${load}${B}${ctx_pct}%${R}"
L1+="  ${C_IN}↑${B}$(kfmt "$ctx_used")${R}  ${C_OUT}↓${B}$(kfmt "$tok_out")${R}"
if [ "$sess_out" -gt 0 ] 2>/dev/null; then
    L1+="  ${D}Σ↓${R}${C_OUT}${B}$(kfmt "$sess_out")${R}"
fi

case "$cost" in
    -|0|0.0) ;;
    *) L1+="${SEP}💰 ${C_COST}${B}\$$(printf '%.4f' "$cost")${R}" ;;
esac

L1+="${SEP}📁 ${C_DIR}${B}${folder}${R}"
[ -n "$branch" ] && L1+="  ${D}⎇${R} ${C_GIT}${B}${branch}${R}${edited}"

if [ "${adds:-0}" -gt 0 ] 2>/dev/null || [ "${dels:-0}" -gt 0 ] 2>/dev/null; then
    L1+="  ${C_OK}${B}✚${adds}${R}  ${C_HOT}${B}✖${dels}${R}"
fi

# ── Line 2 ───────────────────────────────────────────────────────────────
L2=''
if [ "$pct5" != "-" ]; then
    p=$(printf '%.0f' "$pct5")
    L2+="⚡ ${D}5h${R} $(meter "$p") $(heat "$p")${B}${p}%${R}"
    t=$(clock_at "$at5")
    [ -n "$t" ] && L2+="  ${D}⟳${R} ${C_TIME}${t}${R}"
fi
if [ "$pct7" != "-" ]; then
    p=$(printf '%.0f' "$pct7")
    [ -n "$L2" ] && L2+="     "
    L2+="📅 ${D}7d${R} $(meter "$p") $(heat "$p")${B}${p}%${R}"
    d=$(day_at "$at7")
    [ -n "$d" ] && L2+="  ${D}⟳${R} ${C_TIME}${d}${R}"
fi

# ── Emit ─────────────────────────────────────────────────────────────────
printf '%s' "$L1"
[ -n "$L2" ] && printf '\n\n%s' "$L2"
exit 0
