#!/usr/bin/env bash
# Claude Code status line for erezm
# Format: ~/path · Model Name · Effort · 5h X% left · Ctx X% · X.XK used

input=$(cat)

# ── ANSI color codes (ANSI-C quoting so bash interprets at parse time) ────────
RESET=$'\033[0m'
COLOR_PATH=$'\033[38;2;59;188;198m'    # teal — path
COLOR_BRANCH=$'\033[38;2;120;160;215m' # blue — git branch
COLOR_MODEL=$'\033[38;2;218;119;86m'   # Claude's signature orange — model name
COLOR_EFFORT=$'\033[38;2;195;155;80m'  # warm amber/golden — effort
COLOR_STATS=$'\033[38;2;150;150;150m'  # grey — usage stats
COLOR_SEP=$'\033[38;2;110;100;90m'     # muted warm gray — separators
COLOR_ADDED=$'\033[38;2;130;190;120m'  # green — lines added in branch diff
COLOR_REMOVED=$'\033[38;2;205;110;80m' # terracotta — lines removed in branch diff

SEP="${COLOR_SEP} · ${RESET}"

parts=()
colors=()

# ── 1. Model display name ─────────────────────────────────────────────────────
model_name=$(echo "$input" | jq -r '.model.display_name // ""')
if [ -n "$model_name" ]; then
  parts+=("$model_name")
  colors+=("$COLOR_MODEL")
fi

# ── 2. Effort level (capitalized) ─────────────────────────────────────────────
effort=$(echo "$input" | jq -r '.effort.level // ""')
if [ -n "$effort" ]; then
  # Capitalize first letter
  effort_cap="$(echo "${effort:0:1}" | tr '[:lower:]' '[:upper:]')${effort:1}"
  parts+=("$effort_cap")
  colors+=("$COLOR_EFFORT")
fi

# ── 3. Path (~ for home, ~/sub/path for subdirs) ──────────────────────────────
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
if [ -n "$cwd" ]; then
  if [ "$cwd" = "$HOME" ]; then
    display_path="~"
  elif [[ "$cwd" == "$HOME/"* ]]; then
    display_path="~${cwd#$HOME}"
  else
    display_path="$cwd"
  fi
  parts+=("$display_path")
  colors+=("$COLOR_PATH")
fi

# ── 3b. Git branch + diff stat, e.g. "main (+42,-10)" ─────────────────────────
branch_part=""
if [ -n "$cwd" ]; then
  branch=$(git -C "$cwd" symbolic-ref --quiet --short HEAD 2>/dev/null \
           || git -C "$cwd" rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    # Lines added/removed across staged + unstaged changes vs HEAD.
    # numstat columns: <added> <removed> <path>; binary files show '-'.
    read -r ins del < <(git -C "$cwd" diff --numstat HEAD 2>/dev/null \
      | awk '{ a += ($1 == "-" ? 0 : $1); d += ($2 == "-" ? 0 : $2) }
             END { print a+0, d+0 }')
    branch_part="${COLOR_BRANCH}${branch}${RESET}"
    if { [ "${ins:-0}" -gt 0 ] || [ "${del:-0}" -gt 0 ]; } 2>/dev/null; then
      branch_part+="${COLOR_SEP} (${RESET}${COLOR_ADDED}+${ins}${RESET}"
      branch_part+="${COLOR_SEP},${RESET}${COLOR_REMOVED}-${del}${RESET}"
      branch_part+="${COLOR_SEP})${RESET}"
    fi
    # branch_part is already fully colored, so its color slot is empty.
    parts+=("$branch_part")
    colors+=("")
  fi
fi

# ── 4. 5-hour window % remaining ──────────────────────────────────────────────
five_used=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
if [ -n "$five_used" ] && [ "$five_used" != "null" ]; then
  five_left=$(awk "BEGIN { printf \"%.0f\", 100 - $five_used }")
  parts+=("5h ${five_left}% left")
  colors+=("$COLOR_STATS")
fi

# ── 5. Context % used ─────────────────────────────────────────────────────────
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$ctx_pct" ] && [ "$ctx_pct" != "null" ]; then
  ctx_rounded=$(awk "BEGIN { printf \"%.0f\", $ctx_pct }")
  parts+=("Ctx ${ctx_rounded}%")
  colors+=("$COLOR_STATS")
fi

# ── 6. Total tokens used (input + output, formatted as e.g. 22.1K) ────────────
total_tokens=$(echo "$input" | jq -r '
  ((.context_window.total_input_tokens // 0) +
   (.context_window.total_output_tokens // 0))' 2>/dev/null)
if [ -n "$total_tokens" ] && [ "$total_tokens" != "null" ] && [ "$total_tokens" -gt 0 ] 2>/dev/null; then
  tok_fmt=$(awk "BEGIN { v = $total_tokens / 1000; if (v == int(v)) printf \"%dK\", v; else printf \"%.1fK\", v }")
  parts+=("${tok_fmt} used")
  colors+=("$COLOR_STATS")
fi

# ── Terminal width (fall back to 120 if tput unavailable) ────────────────────
TERM_WIDTH=$(tput cols 2>/dev/null)
if [ -z "$TERM_WIDTH" ] || [ "$TERM_WIDTH" -le 0 ] 2>/dev/null; then
  TERM_WIDTH=120
fi

# ── Measure plain-text width of a parts array (no ANSI codes) ────────────────
# Separator plain text is " · " = 3 visible characters
SEP_PLAIN=" · "

measure_width() {
  local -n _pts=$1
  local total=0
  local n=${#_pts[@]}
  for i in "${!_pts[@]}"; do
    local plain
    plain=$(printf '%s' "${_pts[$i]}" | sed 's/\x1b\[[0-9;]*m//g')
    total=$(( total + ${#plain} ))
  done
  if [ "$n" -gt 1 ]; then
    total=$(( total + (n - 1) * ${#SEP_PLAIN} ))
  fi
  echo "$total"
}

# ── Drop low-priority segments until the line fits ────────────────────────────
# Order is: model · effort · path · branch · 5h · ctx · tokens
# When too wide we shed the least essential segments first: branch, then path.
# Everything else (model / effort / stats) is always kept.
drop_segment() {
  # Remove the parts/colors entry whose value matches $1 (first match). Returns
  # 0 if something was removed, 1 otherwise.
  local target=$1 i
  for i in "${!parts[@]}"; do
    if [ "${parts[$i]}" = "$target" ]; then
      parts=("${parts[@]:0:i}" "${parts[@]:i+1}")
      colors=("${colors[@]:0:i}" "${colors[@]:i+1}")
      return 0
    fi
  done
  return 1
}

while true; do
  width=$(measure_width parts)
  if [ "$width" -le "$TERM_WIDTH" ] || [ "${#parts[@]}" -le 1 ]; then
    break
  fi
  # Shed branch first, then path; if neither remains, stop shedding.
  if [ -n "$branch_part" ] && drop_segment "$branch_part"; then
    continue
  elif [ -n "$display_path" ] && drop_segment "$display_path"; then
    continue
  else
    break
  fi
done

# ── Join all segments with colored · separator ────────────────────────────────
result=""
for i in "${!parts[@]}"; do
  if [ "$i" -eq 0 ]; then
    result="${colors[$i]}${parts[$i]}${RESET}"
  else
    result="${result}${SEP}${colors[$i]}${parts[$i]}${RESET}"
  fi
done

printf '%b' "$result"
