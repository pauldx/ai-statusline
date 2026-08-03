#!/usr/bin/env bash
# Two-line status line for GitHub Copilot CLI.
set -u
set -f

json=$(cat 2>/dev/null || true)
if [ -z "$json" ]; then
    printf '🤖 Copilot'
    exit 0
fi

ESC=$'\033'
R="${ESC}[0m" B="${ESC}[1m" D="${ESC}[2m"
c() { printf '%s[38;5;%sm' "$ESC" "$1"; }
C_MODEL=$(c 33) C_IN=$(c 37) C_OUT=$(c 135) C_DIR=$(c 37)
C_GIT=$(c 35) C_HOT=$(c 160) C_OK=$(c 35) C_TIME=$(c 102)
SEP=" ${D}│${R} "

heat() {
    local pct=$1
    if   [ "$pct" -ge 90 ]; then c 160
    elif [ "$pct" -ge 70 ]; then c 178
    elif [ "$pct" -ge 50 ]; then c 208
    else                           c 35
    fi
}

meter() {
    local pct=$1 width=${2:-8}
    [ "$pct" -lt 0 ] 2>/dev/null && pct=0
    [ "$pct" -gt 100 ] 2>/dev/null && pct=100
    local filled=$(( pct * width / 100 ))
    local solid='████████████████' faint='░░░░░░░░░░░░░░░░'
    printf '%s%s%s%s%s' "$(heat "$pct")" "${solid:0:filled}" "$D" \
        "${faint:0:width-filled}" "$R"
}

kfmt() {
    awk -v n="${1:-0}" 'BEGIN {
        if (n >= 1000) { v = n / 1000; printf((v == int(v)) ? "%dk" : "%.1fk", v) }
        else printf("%d", n)
    }'
}

duration() {
    local seconds=$(( ${1:-0} / 1000 ))
    if [ "$seconds" -ge 3600 ]; then
        printf '%dh%02dm' "$(( seconds / 3600 ))" "$(( seconds % 3600 / 60 ))"
    elif [ "$seconds" -ge 60 ]; then
        printf '%dm%02ds' "$(( seconds / 60 ))" "$(( seconds % 60 ))"
    else
        printf '%ds' "$seconds"
    fi
}

IFS=$'\t' read -r model cwd tok_in tok_out ctx_pct ai_used duration_ms adds dels \
    remote allow_all version < <(
    jq -r '[
        (.model.display_name // .model.id // "Copilot"),
        (.workspace.current_dir // .cwd // "-"),
        (.context_window.total_input_tokens // 0),
        (.context_window.total_output_tokens // 0),
        (.context_window.used_percentage // "-"),
        (.ai_used.formatted // "0"),
        (.cost.total_duration_ms // 0),
        (.cost.total_lines_added // 0),
        (.cost.total_lines_removed // 0),
        (.remote.connected // false),
        (.allow_all_enabled // false),
        (.version // "-")
    ] | map(if . == "" then "-" else . end) | @tsv' <<<"$json" 2>/dev/null
) || true

: "${model:=Copilot}" "${cwd:=$PWD}" "${tok_in:=0}" "${tok_out:=0}"
: "${ctx_pct:=-}" "${ai_used:=0}" "${duration_ms:=0}" "${adds:=0}" "${dels:=0}"
: "${remote:=false}" "${allow_all:=false}" "${version:=-}"

folder=${cwd##*/}
branch=$(git -C "$cwd" branch --show-current 2>/dev/null || true)
edited=''
if [ -n "$branch" ] && [ -n "$(git -C "$cwd" --no-optional-locks status --porcelain 2>/dev/null)" ]; then
    edited=" ${C_HOT}✎${R}"
fi

L1="${B}${C_MODEL}🤖 ${model}${R}"
if [ "$ctx_pct" != "-" ] && [ "$ctx_pct" != "null" ]; then
    pct=$(printf '%.0f' "$ctx_pct")
    L1+="${SEP}🧠 $(meter "$pct") $(heat "$pct")${B}${pct}%${R}"
fi
L1+="${SEP}${C_IN}↑${B}$(kfmt "$tok_in")${R}  ${C_OUT}↓${B}$(kfmt "$tok_out")${R}"
[ "$ai_used" != "0" ] && L1+="  ${D}AI${R} ${B}${ai_used}${R}"
L1+="${SEP}📁 ${C_DIR}${B}${folder}${R}"
[ -n "$branch" ] && L1+="  ${D}⎇${R} ${C_GIT}${B}${branch}${R}${edited}"
if [ "$adds" -gt 0 ] 2>/dev/null || [ "$dels" -gt 0 ] 2>/dev/null; then
    L1+="  ${C_OK}${B}✚${adds}${R}  ${C_HOT}${B}✖${dels}${R}"
fi

L2="⏱ ${C_TIME}$(duration "$duration_ms")${R}"
[ "$version" != "-" ] && L2+="${SEP}${D}Copilot v${version}${R}"
[ "$remote" = "true" ] && L2+="${SEP}${C_OK}${B}remote${R}"
[ "$allow_all" = "true" ] && L2+="${SEP}${C_HOT}${B}YOLO${R}"

printf '%s\n%s' "$L1" "$L2"