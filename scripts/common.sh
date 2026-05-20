#!/usr/bin/env bash
# Cross-platform steps shared between macOS and Linux.
# Expects DOTFILES_DIR and ZSH_BIN to be set by the calling platform script.
# Assumes git, stow, and zsh are already installed.
#
# DRY_RUN=1 to print intent without mutating filesystem state.

: "${DOTFILES_DIR:?DOTFILES_DIR must be set}"
: "${ZSH_BIN:?ZSH_BIN must be set (e.g., /opt/homebrew/bin/zsh or /usr/bin/zsh)}"
DRY_RUN="${DRY_RUN:-0}"

ZDOTDIR_PATH="$HOME/.config/zsh"

# --- zdotdir clone --------------------------------------------------------
if [ -d "$ZDOTDIR_PATH" ]; then
    echo "zdotdir already at $ZDOTDIR_PATH, skipping clone."
elif [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] would clone https://github.com/tom21100227/zdotdir to $ZDOTDIR_PATH"
else
    echo "Cloning zdotdir to $ZDOTDIR_PATH..."
    git clone https://github.com/tom21100227/zdotdir "$ZDOTDIR_PATH"
fi

# --- .zshenv pointer ------------------------------------------------------
expected_zshenv=". \"$ZDOTDIR_PATH/.zshenv\""
if [ ! -f "$HOME/.zshenv" ] || [ "$(cat "$HOME/.zshenv" 2>/dev/null)" != "$expected_zshenv" ]; then
    if [ "$DRY_RUN" = "1" ]; then
        echo "[dry-run] would write .zshenv pointing at $ZDOTDIR_PATH/.zshenv"
    else
        if [ -f "$HOME/.zshenv" ] && [ ! -L "$HOME/.zshenv" ] && [ ! -e "$HOME/.zshenv.bak" ]; then
            echo "Backing up existing .zshenv to .zshenv.bak"
            mv "$HOME/.zshenv" "$HOME/.zshenv.bak"
        fi
        printf '%s\n' "$expected_zshenv" > "$HOME/.zshenv"
    fi
fi

# --- back up any non-symlink files that stow would conflict with ----------
backup_if_conflict() {
    local target="$1"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        if [ -e "${target}.bak" ]; then
            echo "Skipping backup of $target (${target}.bak already exists)"
        elif [ "$DRY_RUN" = "1" ]; then
            echo "[dry-run] would back up $target to ${target}.bak"
        else
            echo "Backing up existing $target to ${target}.bak"
            mv "$target" "${target}.bak"
        fi
    fi
}
if [ "$DRY_RUN" != "1" ]; then
    mkdir -p "$HOME/.claude" "$HOME/.config"
fi
backup_if_conflict "$HOME/.claude/settings.json"
backup_if_conflict "$HOME/.claude/statusline.sh"
backup_if_conflict "$HOME/.condarc"

# --- stow the dotfiles into $HOME -----------------------------------------
if ! command -v stow &>/dev/null; then
    if [ "$DRY_RUN" = "1" ]; then
        echo "[dry-run] stow not installed yet; would stow $DOTFILES_DIR -> $HOME"
    else
        echo "ERROR: stow is not installed" >&2
        exit 1
    fi
else
    stow_args=(-v -t "$HOME")
    [ "$DRY_RUN" = "1" ] && stow_args=(-n "${stow_args[@]}")
    echo "Stowing dotfiles${DRY_RUN:+ (dry-run)}..."
    ( cd "$DOTFILES_DIR" && stow "${stow_args[@]}" . )
fi

# --- ensure zsh is a registered login shell and set as default ------------
if ! grep -qxF "$ZSH_BIN" /etc/shells; then
    if [ "$DRY_RUN" = "1" ]; then
        echo "[dry-run] would add $ZSH_BIN to /etc/shells"
    else
        echo "Adding $ZSH_BIN to /etc/shells"
        echo "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null
    fi
fi

current_shell=""
if command -v getent &>/dev/null; then
    current_shell=$(getent passwd "$USER" | cut -d: -f7)
elif command -v dscl &>/dev/null; then
    current_shell=$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')
fi

if [ "$current_shell" != "$ZSH_BIN" ]; then
    if [ "$DRY_RUN" = "1" ]; then
        echo "[dry-run] would set login shell to $ZSH_BIN"
    else
        echo "Setting login shell to $ZSH_BIN"
        sudo chsh -s "$ZSH_BIN" "$USER"
    fi
else
    echo "Login shell is already $ZSH_BIN."
fi
