#!/usr/bin/env bash
# Cross-platform steps shared between macOS and Linux.
# Expects DOTFILES_DIR and ZSH_BIN to be set by the calling platform script.
# Assumes git, stow, and zsh are already installed.

: "${DOTFILES_DIR:?DOTFILES_DIR must be set}"
: "${ZSH_BIN:?ZSH_BIN must be set (e.g., /opt/homebrew/bin/zsh or /usr/bin/zsh)}"

ZDOTDIR_PATH="$HOME/.config/zsh"

# --- zdotdir clone --------------------------------------------------------
if [ -d "$ZDOTDIR_PATH" ]; then
    echo "zdotdir already at $ZDOTDIR_PATH, skipping clone."
else
    echo "Cloning zdotdir to $ZDOTDIR_PATH..."
    git clone https://github.com/tom21100227/zdotdir "$ZDOTDIR_PATH"
fi

# --- .zshenv pointer ------------------------------------------------------
expected_zshenv=". \"$ZDOTDIR_PATH/.zshenv\""
if [ ! -f "$HOME/.zshenv" ] || [ "$(cat "$HOME/.zshenv" 2>/dev/null)" != "$expected_zshenv" ]; then
    if [ -f "$HOME/.zshenv" ] && [ ! -L "$HOME/.zshenv" ] && [ ! -e "$HOME/.zshenv.bak" ]; then
        echo "Backing up existing .zshenv to .zshenv.bak"
        mv "$HOME/.zshenv" "$HOME/.zshenv.bak"
    fi
    printf '%s\n' "$expected_zshenv" > "$HOME/.zshenv"
fi

# --- back up any non-symlink files that stow would conflict with ----------
backup_if_conflict() {
    local target="$1"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        if [ -e "${target}.bak" ]; then
            echo "Skipping backup of $target (${target}.bak already exists)"
        else
            echo "Backing up existing $target to ${target}.bak"
            mv "$target" "${target}.bak"
        fi
    fi
}
mkdir -p "$HOME/.claude" "$HOME/.config"
backup_if_conflict "$HOME/.claude/settings.json"
backup_if_conflict "$HOME/.claude/statusline.sh"
backup_if_conflict "$HOME/.condarc"

# --- stow the dotfiles into $HOME -----------------------------------------
echo "Stowing dotfiles..."
( cd "$DOTFILES_DIR" && stow -v -t "$HOME" . )

# --- ensure zsh is a registered login shell and set as default ------------
if ! grep -qxF "$ZSH_BIN" /etc/shells; then
    echo "Adding $ZSH_BIN to /etc/shells"
    echo "$ZSH_BIN" | sudo tee -a /etc/shells >/dev/null
fi

current_shell=""
if command -v getent &>/dev/null; then
    current_shell=$(getent passwd "$USER" | cut -d: -f7)
elif command -v dscl &>/dev/null; then
    current_shell=$(dscl . -read "/Users/$USER" UserShell 2>/dev/null | awk '{print $2}')
fi

if [ "$current_shell" != "$ZSH_BIN" ]; then
    echo "Setting login shell to $ZSH_BIN"
    sudo chsh -s "$ZSH_BIN" "$USER"
else
    echo "Login shell is already $ZSH_BIN."
fi
