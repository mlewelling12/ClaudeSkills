#!/bin/bash
# Claude Code status line script
#
# Reads JSON session data from stdin and outputs a colored status bar:
#   Model | dir@branch (+added -removed) | tokens/max (%) | effort | +lines -lines | api:time | $cost
#
# Setup — add to ~/.claude/settings.json:
#   { "statusLine": { "command": "bash /path/to/statusline.sh" } }
#
# Input — Claude Code pipes JSON like this to stdin:
#   {
#     "model": { "display_name": "Opus 4.6" },
#     "cwd": "/path/to/project",
#     "context_window": {
#       "context_window_size": 200000,
#       "current_usage": { "input_tokens": 30000, "cache_creation_input_tokens": 5000, "cache_read_input_tokens": 11000 }
#     },
#     "cost": { "total_cost_usd": 1.23, "total_lines_added": 50, "total_lines_removed": 10, "total_api_duration_ms": 95000 }
#   }
#
# Requirements: jq, git

set -f  # Disable globbing to avoid expanding wildcards in JSON values

# Read JSON session data from stdin
input=$(cat)

# Fallback when no data is available (e.g. during startup)
if [ -z "$input" ]; then
    printf "Claude"
    exit 0
fi

# ── Colors (ANSI 24-bit / truecolor) ──
blue='\033[38;2;0;153;255m'
orange='\033[38;2;255;176;85m'
green='\033[38;2;0;160;0m'
cyan='\033[38;2;46;149;153m'
red='\033[38;2;255;85;85m'
dim='\033[2m'
reset='\033[0m'

# Formats a token count for display: 1500000 → "1.5m", 46000 → "46k", 800 → "800"
format_tokens() {
    local num=$1
    if [ "$num" -ge 1000000 ]; then
        awk "BEGIN {printf \"%.1fm\", $num / 1000000}"
    elif [ "$num" -ge 1000 ]; then
        awk "BEGIN {printf \"%.0fk\", $num / 1000}"
    else
        printf "%d" "$num"
    fi
}

# Returns a color code based on how full the context window is
usage_color() {
    local pct=$1
    if [ "$pct" -ge 80 ]; then echo "$red"
    elif [ "$pct" -ge 50 ]; then echo "$orange"
    else echo "$green"
    fi
}

# ── Extract all values from JSON in one pass ──
# Uses jq's @sh to produce shell-safe quoted assignments, then eval sets them as variables.
# This avoids spawning a separate jq process for each field.
eval "$(echo "$input" | jq -r '
  @sh "model_name=\(.model.display_name // "Claude")",
  @sh "cwd=\(.cwd // "")",
  @sh "size=\(.context_window.context_window_size // 200000)",
  @sh "input_tokens=\(.context_window.current_usage.input_tokens // 0)",
  @sh "cache_create=\(.context_window.current_usage.cache_creation_input_tokens // 0)",
  @sh "cache_read=\(.context_window.current_usage.cache_read_input_tokens // 0)",
  @sh "lines_added=\(.cost.total_lines_added // 0)",
  @sh "lines_removed=\(.cost.total_lines_removed // 0)",
  @sh "api_ms=\(.cost.total_api_duration_ms // 0)",
  @sh "cost_usd=\(.cost.total_cost_usd // 0)"
')"

# Total tokens = input + cached (creation + reads)
[ "$size" -eq 0 ] 2>/dev/null && size=200000
current=$(( input_tokens + cache_create + cache_read ))
used_tokens=$(format_tokens "$current")
total_tokens=$(format_tokens "$size")
if [ "$size" -gt 0 ]; then
    pct_used=$(( current * 100 / size ))
else
    pct_used=0
fi

# Reasoning effort level (env var > settings file > default "high")
effort_level="high"
if [ -n "$CLAUDE_CODE_EFFORT_LEVEL" ]; then
    effort_level="$CLAUDE_CODE_EFFORT_LEVEL"
elif [ -f "$HOME/.claude/settings.json" ]; then
    effort_val=$(jq -r '.effortLevel // empty' "$HOME/.claude/settings.json" 2>/dev/null)
    [ -n "$effort_val" ] && effort_level="$effort_val"
fi

# ── Build the status line ──

# Model name
out="${blue}${model_name}${reset}"

# Working directory and git branch with uncommitted change counts
if [ -n "$cwd" ]; then
    dir_name="${cwd##*/}"
    out+=" ${dim}|${reset} ${cyan}${dir_name}${reset}"

    branch=$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        out+="${dim}@${reset}${green}${branch}${reset}"

        # Count lines added/removed in uncommitted changes
        added=0 removed=0
        read -r added removed < <(git -C "$cwd" diff --numstat 2>/dev/null | awk '{a+=$1; d+=$2} END {print a+0, d+0}')
        if [ "$added" -gt 0 ] || [ "$removed" -gt 0 ]; then
            out+=" ${dim}(${reset}${green}+${added}${reset} ${red}-${removed}${reset}${dim})${reset}"
        fi
    fi
fi

# Token usage with color-coded percentage
pct_color=$(usage_color "$pct_used")
out+=" ${dim}|${reset} ${orange}${used_tokens}/${total_tokens}${reset} ${dim}(${reset}${pct_color}${pct_used}%${reset}${dim})${reset}"

# Effort level
out+=" ${dim}|${reset} effort: "
case "$effort_level" in
    low)    out+="${dim}low${reset}" ;;
    medium) out+="${orange}med${reset}" ;;
    *)      out+="${green}high${reset}" ;;
esac

# Lines changed in this session
if [ "$lines_added" -gt 0 ] || [ "$lines_removed" -gt 0 ]; then
    out+=" ${dim}|${reset} ${green}+${lines_added}${reset} ${red}-${lines_removed}${reset}"
fi

# Total API response time
if [ "$api_ms" -gt 0 ]; then
    if [ "$api_ms" -ge 60000 ]; then
        api_time=$(awk "BEGIN {printf \"%.1fm\", $api_ms / 60000}")
    else
        api_time=$(awk "BEGIN {printf \"%.1fs\", $api_ms / 1000}")
    fi
    out+=" ${dim}|${reset} ${dim}api:${reset}${cyan}${api_time}${reset}"
fi

# Session cost in USD
if [ "$cost_usd" != "0" ] && [ -n "$cost_usd" ]; then
    cost_display=$(awk "BEGIN {printf \"\\$%.2f\", $cost_usd}")
    out+=" ${dim}|${reset} ${dim}session cost: ${reset}${orange}${cost_display}${reset}"
fi

printf "%b" "$out"
exit 0
