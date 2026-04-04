#!/usr/bin/env bash
# Claude Code status line
# Layout: model_id | path | ctx <bar> N% | 5h <bar> N% Xhm | 7d <bar> N% XdYhZm
# Hard cap: 100 visible characters. Requires: jq, awk.

input=$(cat)

# ---------------------------------------------------------------------------
# Extract fields
# ---------------------------------------------------------------------------
model_id=$(echo "$input" | jq -r '.model.id // .model.display_name // "unknown"' | sed 's/^claude-//')
ctx_window=$(echo "$input" | jq -r '.context_window.context_window_size // 200000')
current_dir=$(echo "$input" | jq -r '.workspace.current_dir // ""')
ctx_pct=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
five_pct=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
seven_pct=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
seven_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

# ---------------------------------------------------------------------------
# ANSI color helpers (ANSI-C quoting)
# ---------------------------------------------------------------------------
C_PALE_YELLOW=$'\033[38;5;186m'
C_SOFT_GREEN=$'\033[38;5;114m'
C_SOFT_YELLOW=$'\033[38;5;221m'
C_SOFT_RED=$'\033[38;5;203m'
C_DARK_GREY_BAR=$'\033[38;5;238m'
C_DARK_GREY_TIME=$'\033[38;5;240m'
C_RESET=$'\033[0m'

# ---------------------------------------------------------------------------
# Braille progress bar — 5 chars, 40 fill steps (8 per char)
# Left column first (bottom-up), then right column (bottom-up):
# ⠀ ⡀ ⡄ ⡆ ⡇ ⣇ ⣧ ⣷ ⣿
# $1 = percentage (0-100), $2 = optional fill color override
# ---------------------------------------------------------------------------
braille_bar() {
    local pct="$1"
    local fill_color="${2:-$C_SOFT_GREEN}"
    local fill
    fill=$(awk -v p="$pct" 'BEGIN { v=int(p/100*40+0.5); if(v<0)v=0; if(v>40)v=40; print v }')
    local bar=""
    local remaining="$fill"
    local chars=("⠀" "⡀" "⡄" "⡆" "⡇" "⣇" "⣧" "⣷" "⣿")
    local i level
    for i in 1 2 3 4 5; do
        if [ "$remaining" -ge 8 ]; then
            level=8
        else
            level=$remaining
        fi
        if [ "$level" -gt 0 ]; then
            bar="${bar}${fill_color}${chars[$level]}${C_RESET}"
        else
            bar="${bar}${C_DARK_GREY_BAR}${chars[0]}${C_RESET}"
        fi
        remaining=$(( remaining > level ? remaining - level : 0 ))
    done
    printf '%s' "$bar"
}

# ---------------------------------------------------------------------------
# Reset countdown: XdYhZm, omitting leading zero units
# ---------------------------------------------------------------------------
format_countdown() {
    local epoch="$1"
    local now
    now=$(date +%s)
    local diff=$(( epoch - now ))
    if [ "$diff" -le 0 ]; then
        echo "0m"
        return
    fi
    local days=$(( diff / 86400 ))
    local hours=$(( (diff % 86400) / 3600 ))
    local mins=$(( (diff % 3600) / 60 ))
    if [ "$days" -gt 0 ]; then
        echo "${days}d${hours}h${mins}m"
    elif [ "$hours" -gt 0 ]; then
        echo "${hours}h${mins}m"
    else
        echo "${mins}m"
    fi
}

# ---------------------------------------------------------------------------
# Count visible characters in a string (strip ANSI, count unicode codepoints)
# ---------------------------------------------------------------------------
visible_len() {
    printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g' | wc -m | tr -d ' \n'
}

# ---------------------------------------------------------------------------
# Zsh-style path shortening
# Each non-leaf component is abbreviated to the shortest prefix that
# uniquely matches among sibling dirs. Leaf stays full. HOME -> ~.
# If result still exceeds budget, right-truncate leaf with …
# ---------------------------------------------------------------------------
shorten_path() {
    local full_path="$1"
    local budget="$2"
    local home="$HOME"

    # Replace HOME prefix with ~
    local display_path="${full_path/#$home/\~}"

    # Fast path: already fits
    local dlen
    dlen=$(visible_len "$display_path")
    if [ "$dlen" -le "$budget" ]; then
        printf '%s' "$display_path"
        return
    fi

    # Determine filesystem root for glob walks and display prefix
    local fs_root display_prefix
    if [[ "$full_path" == "$home"* ]]; then
        fs_root="$home"
        display_prefix="~"
    elif [[ "$full_path" == /* ]]; then
        fs_root="/"
        display_prefix="/"
    else
        fs_root="."
        display_prefix=""
    fi

    # Strip the root to get remaining path components
    local stripped="${full_path/#$home\//}"   # strip "HOME/" if present
    if [[ "$full_path" == "$home" ]]; then
        # exactly $HOME
        stripped=""
    elif [[ "$full_path" != "$home"* ]]; then
        stripped="${full_path#/}"
    fi

    # Split into array of components
    IFS='/' read -ra parts <<< "$stripped"
    local n=${#parts[@]}

    if [ "$n" -le 1 ]; then
        # Single component — just truncate if needed
        if [ "$(visible_len "$display_path")" -gt "$budget" ] && [ "$budget" -ge 2 ]; then
            printf '%s' "${display_path:0:$(( budget - 1 ))}…"
        else
            printf '%s' "$display_path"
        fi
        return
    fi

    # Walk all components except the last, abbreviating each
    local abbreviated=()
    local fs_cur="$fs_root"
    local i
    for (( i=0; i < n-1; i++ )); do
        local comp="${parts[$i]}"
        local abbrev=""
        local j
        for (( j=1; j<=${#comp}; j++ )); do
            local pfx="${comp:0:$j}"
            local mc
            mc=$(ls -1d "${fs_cur}/${pfx}"*/ 2>/dev/null | wc -l | tr -d ' ')
            if [ "$mc" -le 1 ]; then
                abbrev="$pfx"
                break
            fi
        done
        [ -z "$abbrev" ] && abbrev="$comp"
        abbreviated+=("$abbrev")
        fs_cur="${fs_cur}/${comp}"
        fs_cur="${fs_cur//\/\//\/}"
    done

    local leaf="${parts[$((n-1))]}"

    # Reconstruct short display path
    local short_path="$display_prefix"
    for (( i=0; i < ${#abbreviated[@]}; i++ )); do
        if [ -z "$short_path" ] || [[ "$short_path" == */ ]]; then
            short_path="${short_path}${abbreviated[$i]}"
        else
            short_path="${short_path}/${abbreviated[$i]}"
        fi
    done
    if [ -z "$short_path" ] || [[ "$short_path" == */ ]]; then
        short_path="${short_path}${leaf}"
    else
        short_path="${short_path}/${leaf}"
    fi
    short_path="${short_path//\/\//\/}"

    local slen
    slen=$(visible_len "$short_path")
    if [ "$slen" -le "$budget" ]; then
        printf '%s' "$short_path"
        return
    fi

    # Still too long — right-truncate the leaf
    local leaf_budget=$(( budget - slen + ${#leaf} - 1 ))
    [ "$leaf_budget" -lt 1 ] && leaf_budget=1
    local trunc_leaf="${leaf:0:$leaf_budget}…"
    # Replace final leaf in short_path
    short_path="${short_path%$leaf}${trunc_leaf}"
    printf '%s' "$short_path"
}

# ---------------------------------------------------------------------------
# Build plain-text versions of each optional segment (for width accounting)
# ---------------------------------------------------------------------------
SEP=" | "
SEP_LEN=3

seg_model="$model_id"

# ---------------------------------------------------------------------------
# Pick color for a bar given percentage and yellow/red thresholds
# ---------------------------------------------------------------------------
bar_color() {
    local pct="$1"
    local yellow_thresh="$2"
    local red_thresh="$3"
    if awk -v p="$pct" -v r="$red_thresh" 'BEGIN { exit !(p >= r) }'; then
        printf '%s' "$C_SOFT_RED"
    elif awk -v p="$pct" -v y="$yellow_thresh" 'BEGIN { exit !(p >= y) }'; then
        printf '%s' "$C_SOFT_YELLOW"
    else
        printf '%s' "$C_SOFT_GREEN"
    fi
}

seg_ctx=""
seg_ctx_plain=""
if [ -n "$ctx_pct" ]; then
    ctx_pct_str=$(awk -v p="$ctx_pct" 'BEGIN { printf "%.0f%%", p }')
    # Thresholds differ by context window size:
    #   1M+ models: yellow @ 20%, red @ 50%
    #   200K models: yellow @ 80%, red @ 90%
    ctx_yellow=80
    ctx_red=90
    if awk -v w="$ctx_window" 'BEGIN { exit !(w >= 500000) }'; then
        ctx_yellow=20
        ctx_red=50
    fi
    seg_ctx="non-empty"   # marker; rendered below with color
    seg_ctx_plain="ctx _____ ${ctx_pct_str}"
fi

seg_five_plain=""
seg_five_pct_str=""
seg_five_countdown=""
if [ -n "$five_pct" ] && [ -n "$five_reset" ]; then
    seg_five_pct_str=$(awk -v p="$five_pct" 'BEGIN { printf "%.0f%%", p }')
    seg_five_countdown=$(format_countdown "$five_reset")
    # Plain segment: "5h " + 5 braille chars (1 col each) + " " + pct + " " + countdown
    seg_five_plain="5h _____ ${seg_five_pct_str} ${seg_five_countdown}"
fi

seg_seven_plain=""
seg_seven_pct_str=""
seg_seven_countdown=""
if [ -n "$seven_pct" ] && [ -n "$seven_reset" ]; then
    seg_seven_pct_str=$(awk -v p="$seven_pct" 'BEGIN { printf "%.0f%%", p }')
    seg_seven_countdown=$(format_countdown "$seven_reset")
    seg_seven_plain="7d _____ ${seg_seven_pct_str} ${seg_seven_countdown}"
fi

# ---------------------------------------------------------------------------
# Budget calculation
# Fixed width = model + ctx + five + seven + separators
# Remaining goes to path (floor 8)
# ---------------------------------------------------------------------------
len_model=$(visible_len "$seg_model")
len_ctx=0
# ctx segment: "ctx " (4) + bar (5 cols) + " " (1) + pct_str
if [ -n "$seg_ctx" ]; then
    len_ctx=$(( 4 + 5 + 1 + ${#ctx_pct_str} ))
fi

# Each rate-limit segment: "5h " (3) + bar (5 cols) + " " (1) + pct + " " (1) + countdown
len_five=0
if [ -n "$seg_five_plain" ]; then
    len_five=$(( 3 + 5 + 1 + ${#seg_five_pct_str} + 1 + ${#seg_five_countdown} ))
fi
len_seven=0
if [ -n "$seg_seven_plain" ]; then
    len_seven=$(( 3 + 5 + 1 + ${#seg_seven_pct_str} + 1 + ${#seg_seven_countdown} ))
fi

num_seps=1   # always: model | path
[ -n "$seg_ctx" ]         && num_seps=$(( num_seps + 1 ))
[ -n "$seg_five_plain" ]  && num_seps=$(( num_seps + 1 ))
[ -n "$seg_seven_plain" ] && num_seps=$(( num_seps + 1 ))

fixed_width=$(( len_model + len_ctx + len_five + len_seven + num_seps * SEP_LEN ))
path_budget=$(( 100 - fixed_width ))
[ "$path_budget" -lt 8 ] && path_budget=8

# ---------------------------------------------------------------------------
# Shorten the path to budget
# ---------------------------------------------------------------------------
short_path=$(shorten_path "$current_dir" "$path_budget")

# ---------------------------------------------------------------------------
# Assemble final output with colors
# ---------------------------------------------------------------------------
out="${seg_model}${SEP}${short_path}"

if [ -n "$seg_ctx" ]; then
    ctx_col=$(bar_color "$ctx_pct" "$ctx_yellow" "$ctx_red")
    bar_ctx=$(braille_bar "$ctx_pct" "$ctx_col")
    out="${out}${SEP}ctx ${bar_ctx} ${ctx_col}${ctx_pct_str}${C_RESET}"
fi

if [ -n "$seg_five_plain" ]; then
    five_col=$(bar_color "$five_pct" 50 80)
    bar5=$(braille_bar "$five_pct" "$five_col")
    out="${out}${SEP}5h ${bar5} ${five_col}${seg_five_pct_str}${C_RESET} ${C_DARK_GREY_TIME}${seg_five_countdown}${C_RESET}"
fi

if [ -n "$seg_seven_plain" ]; then
    seven_col=$(bar_color "$seven_pct" 50 80)
    bar7=$(braille_bar "$seven_pct" "$seven_col")
    out="${out}${SEP}7d ${bar7} ${seven_col}${seg_seven_pct_str}${C_RESET} ${C_DARK_GREY_TIME}${seg_seven_countdown}${C_RESET}"
fi

printf '%s' "$out"
