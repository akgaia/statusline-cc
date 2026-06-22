#!/bin/bash
# Claude Code Statusline — calm by default, color = attention needed
input=$(cat)

# Optional: dump the raw JSON payload for debugging (set STATUSLINE_DEBUG=1).
# Useful when extending the script and you want to inspect the fields Claude
# Code passes in. Off by default so the script has no side effects.
[ -n "$STATUSLINE_DEBUG" ] && echo "$input" > /tmp/claude-statusline-last-payload.json

# Parse all JSON fields in a single node call.
# IMPORTANT: values that may contain spaces (MODEL_NAME, PROJ_FOLDER) are
# shell-quoted in the node output so that eval handles them correctly.
eval "$(echo "$input" | node -e "
const d = JSON.parse(require('fs').readFileSync(0,'utf8'));
const g = (p,fb) => { const v = p.split('.').reduce((o,k)=>o&&o[k],d); return (v===undefined||v===null)?fb:v; };
const q = s => \"'\" + String(s).replace(/'/g,\"'\\\\''\")+\"'\";
// used_percentage is null until first API call; default to 0 until then
const usedPct = g('context_window.used_percentage', null);
console.log('CTX_PCT='+(usedPct !== null ? Math.floor(usedPct) : 0));
// Session-cumulative token totals
console.log('IN_TOK='+g('context_window.total_input_tokens',0));
console.log('OUT_TOK='+g('context_window.total_output_tokens',0));
console.log('CACHE_TOK='+g('context_window.current_usage.cache_read_input_tokens',0));
console.log('DURATION_MS='+g('cost.total_duration_ms',0));
console.log('RESET_AT='+g('rate_limits.five_hour.resets_at',0));
const fh=g('rate_limits.five_hour.used_percentage',null);
const sd=g('rate_limits.seven_day.used_percentage',null);
console.log('FIVE_H='+(fh!==null?Math.round(fh):''));
console.log('SEVEN_D='+(sd!==null?Math.round(sd):''));
// Model short name: strip 'Claude ' prefix, keep e.g. 'Sonnet 4.6'
const model=g('model.display_name','');
// e.g. 'Claude Opus 4.7 (1M context)' -> 'Opus 4.7'
const shortModel=model.replace(/^Claude\s+/i,'').replace(/\s*\(.*\)\s*$/,'').trim();
console.log('MODEL_NAME='+q(shortModel));
// Reasoning effort (low|medium|high|xhigh|max); absent for models without effort
console.log('EFFORT='+q(g('effort.level','')));
// Project folder: last component of current_dir or cwd
const cwd=g('workspace.current_dir','')||g('cwd','');
const folder=cwd.split(/[\\\\/]/).filter(Boolean).pop()||'';
console.log('PROJ_FOLDER='+q(folder));
" 2>/tmp/claude-statusline-node-err.log)"

# Defaults if parsing failed
: "${CTX_PCT:=0}" "${IN_TOK:=0}" "${OUT_TOK:=0}" "${CACHE_TOK:=0}" "${DURATION_MS:=0}" "${RESET_AT:=0}"

# --- Colors ---
RST='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
YELLOW='\033[33m'
RED='\033[31m'
CYAN='\033[36m'
MAGENTA='\033[35m'
WHITE='\033[37m'
GREEN='\033[32m'

# --- Threshold color: dim when OK, yellow at warning, red at danger ---
thresh_color() {
    local val=$1 warn=$2 crit=$3
    if [ "$val" -ge "$crit" ]; then echo "$RED$BOLD"
    elif [ "$val" -ge "$warn" ]; then echo "$YELLOW"
    else echo "$DIM"; fi
}

# --- Highlighted threshold: bold green when OK (anchor point), yellow, red ---
thresh_color_important() {
    local val=$1 warn=$2 crit=$3
    if [ "$val" -ge "$crit" ]; then echo "$RED$BOLD"
    elif [ "$val" -ge "$warn" ]; then echo "$YELLOW$BOLD"
    else echo "$GREEN$BOLD"; fi
}

CTX_COLOR=$(thresh_color_important "$CTX_PCT" 70 90)

# --- Format tokens (K) ---
fmt_tok() {
    local t=$1
    if [ "$t" -ge 1000 ]; then echo "$((t / 1000))k"
    else echo "$t"; fi
}
IN_FMT=$(fmt_tok "$IN_TOK")
OUT_FMT=$(fmt_tok "$OUT_TOK")
CACHE_FMT=$(fmt_tok "$CACHE_TOK")

# --- New session at (local time of 5h window reset) ---
if [ "$RESET_AT" -gt 0 ]; then
    RESET_TIME=$(date -d "@$RESET_AT" "+%-I:%M%P" 2>/dev/null || date -r "$RESET_AT" "+%-I:%M%P" 2>/dev/null)
else
    RESET_TIME=""
fi

# --- Git info (cached 5s) ---
CACHE_FILE="/tmp/claude-statusline-git"
CACHE_MAX=5
NOW=$(date +%s)
CACHE_MTIME=0
if [ -f "$CACHE_FILE" ]; then
    CACHE_MTIME=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
fi
if [ $((NOW - CACHE_MTIME)) -gt $CACHE_MAX ]; then
    if git rev-parse --git-dir > /dev/null 2>&1; then
        BRANCH=$(git branch --show-current 2>/dev/null)
        STAGED=$(git diff --cached --numstat 2>/dev/null | wc -l | tr -d ' ')
        MODIFIED=$(git diff --numstat 2>/dev/null | wc -l | tr -d ' ')
        echo "$BRANCH|$STAGED|$MODIFIED" > "$CACHE_FILE"
    else
        echo "||" > "$CACHE_FILE"
    fi
fi
IFS='|' read -r BRANCH STAGED MODIFIED < "$CACHE_FILE"

GIT_INFO=""
if [ -n "$BRANCH" ]; then
    GIT_INFO="${CYAN}${BRANCH}${RST}"
    [ "$STAGED" -gt 0 ] && GIT_INFO="${GIT_INFO} ${CYAN}+${STAGED}${RST}"
    [ "$MODIFIED" -gt 0 ] && GIT_INFO="${GIT_INFO} ${YELLOW}~${MODIFIED}${RST}"
fi

# --- Rate limits (dim when OK, yellow 60%+, red+bold 80%+) ---
LIMIT_5H=""
LIMIT_7D=""
if [ -n "$FIVE_H" ]; then
    RL5_C=$(thresh_color_important "$FIVE_H" 60 80)
    LIMIT_5H="${RL5_C}5h:${FIVE_H}%${RST}"
fi
if [ -n "$SEVEN_D" ]; then
    RL7_C=$(thresh_color "$SEVEN_D" 60 80)
    LIMIT_7D="${RL7_C}7d:${SEVEN_D}%${RST}"
fi

# --- Single line: each field separated, none grouped ---
SEP=" ${DIM}│${RST} "
OUT=""
[ -n "$PROJ_FOLDER" ] && OUT="${DIM}${PROJ_FOLDER}${RST}"
[ -n "$GIT_INFO" ]   && OUT="${OUT:+$OUT$SEP}${GIT_INFO}"
if [ -n "$MODEL_NAME" ]; then
    MODEL_DISP="$MODEL_NAME"
    [ -n "$EFFORT" ] && MODEL_DISP="$MODEL_NAME $EFFORT"
    OUT="${OUT:+$OUT$SEP}${DIM}${MODEL_DISP}${RST}"
fi
[ -n "$LIMIT_5H" ]   && OUT="${OUT:+$OUT$SEP}${LIMIT_5H}"
[ -n "$LIMIT_7D" ]   && OUT="${OUT:+$OUT$SEP}${LIMIT_7D}"
OUT="${OUT:+$OUT$SEP}${CTX_COLOR}ctx:${CTX_PCT}%${RST}"
OUT="${OUT}${SEP}${DIM}↓${IN_FMT}${RST}"
OUT="${OUT}${SEP}${DIM}↑${OUT_FMT}${RST}"
OUT="${OUT}${SEP}${DIM}cache:${CACHE_FMT}${RST}"
[ -n "$RESET_TIME" ] && OUT="${OUT}${SEP}${DIM}New ${RESET_TIME}${RST}"

echo -e "$OUT"
