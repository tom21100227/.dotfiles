#!/bin/bash

# Read JSON input from stdin
input=$(cat)

# Extract model information
model_name=$(echo "$input" | jq -r '.model.id // "Unknown Model"')

# Extract current working directory
cwd=$(echo "$input" | jq -r '.cwd // "."')

# Extract context window information
used_percentage=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
total_input=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
total_output=$(echo "$input" | jq -r '.context_window.total_output_tokens // 0')
context_window_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')

# Calculate total tokens used
tokens_used=$((total_input + total_output))

# Calculate cost estimate based on model pricing (as of Jan 2025)
calculate_cost() {
    local model=$1
    local input_tokens=$2
    local output_tokens=$3

    # Pricing per million tokens
    local input_price=0
    local output_price=0

    case "$model" in
        claude-opus-4-6*)
            input_price=5.00
            output_price=25.00
            ;;
        claude-sonnet-4-6*)
            input_price=3.00
            output_price=15.00
            ;;
        claude-haiku-4-5*)
            input_price=1.00
            output_price=5.00
            ;;
        claude-opus-4-5*)
            input_price=5.00
            output_price=25.00
            ;;
        claude-sonnet-4-5*)
            input_price=3.00
            output_price=15.00
            ;;
        claude-3-7-sonnet*)
            input_price=3.00
            output_price=15.00
            ;;
        claude-3-5-sonnet*)
            input_price=3.00
            output_price=15.00
            ;;
        claude-3-5-haiku*)
            input_price=1.00
            output_price=5.00
            ;;
        claude-3-opus*)
            input_price=15.00
            output_price=75.00
            ;;
        claude-3-sonnet*)
            input_price=3.00
            output_price=15.00
            ;;
        claude-3-haiku*)
            input_price=0.25
            output_price=1.25
            ;;
        *)
            # Default to Sonnet pricing if unknown
            input_price=3.00
            output_price=15.00
            ;;
    esac

    # Calculate cost in cents
    local input_cost=$(echo "scale=4; $input_tokens * $input_price / 1000000" | bc)
    local output_cost=$(echo "scale=4; $output_tokens * $output_price / 1000000" | bc)
    local total_cost=$(echo "scale=2; $input_cost + $output_cost" | bc)

    # Format the cost
    if [ $(echo "$total_cost < 0.01" | bc) -eq 1 ]; then
        echo "<\$0.01"
    else
        printf "$%.2f" "$total_cost"
    fi
}

cost_estimate=$(calculate_cost "$model_name" "$total_input" "$total_output")

# Format token counts in k format
format_tokens() {
    local tokens=$1
    if [ "$tokens" -ge 1000 ]; then
        echo "$((tokens / 1000))k"
    else
        echo "$tokens"
    fi
}

tokens_used_fmt=$(format_tokens $tokens_used)
context_size_fmt=$(format_tokens $context_window_size)

# Get git repository and branch information
get_git_info() {
    cd "$cwd" 2>/dev/null || return

    # Check if we're in a git repository
    if git rev-parse --git-dir > /dev/null 2>&1; then
        # Get the repository name (basename of the git root directory)
        repo_root=$(git rev-parse --show-toplevel 2>/dev/null)
        repo_name=$(basename "$repo_root" 2>/dev/null)

        # Get the current branch name
        branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

        if [ -n "$repo_name" ] && [ -n "$branch" ]; then
            echo "$repo_name:$branch"
        fi
    fi
}

git_info=$(get_git_info)

# If no messages yet, show empty bar
if [ -z "$used_percentage" ]; then
    if [ -n "$git_info" ]; then
        echo "[          ] 0% (0/$context_size_fmt) | Cost: \$0.00 | $git_info | $model_name"
    else
        echo "[          ] 0% (0/$context_size_fmt) | Cost: \$0.00 | $model_name"
    fi
    exit 0
fi

# Convert to integer for calculations
used_int=$(printf "%.0f" "$used_percentage")

# Progress bar configuration
bar_width=20
filled_count=$((used_int * bar_width / 100))
empty_count=$((bar_width - filled_count))

# Build the progress bar
filled=$(printf '█%.0s' $(seq 1 $filled_count))
empty=$(printf '░%.0s' $(seq 1 $empty_count))

# Color based on usage level
if [ "$used_int" -ge 90 ]; then
    # Red for high usage (90-100%)
    color="\033[31m"
elif [ "$used_int" -ge 70 ]; then
    # Yellow for moderate usage (70-89%)
    color="\033[33m"
else
    # Green for low usage (0-69%)
    color="\033[32m"
fi
reset="\033[0m"

# Output the status line with reordered elements
if [ -n "$git_info" ]; then
    printf "${color}[%s%s] %d%% (%s/%s)${reset} | Cost: %s | %s | %s\n" "$filled" "$empty" "$used_int" "$tokens_used_fmt" "$context_size_fmt" "$cost_estimate" "$git_info" "$model_name"
else
    printf "${color}[%s%s] %d%% (%s/%s)${reset} | Cost: %s | %s\n" "$filled" "$empty" "$used_int" "$tokens_used_fmt" "$context_size_fmt" "$cost_estimate" "$model_name"
fi
