#!/usr/bin/env bash
# Linux/Ubuntu setup. Invoke via the top-level setup.sh (which exports
# DOTFILES_DIR). Runs as the user; sudo prompts inline for apt + chsh.

set -euo pipefail

: "${DOTFILES_DIR:?DOTFILES_DIR must be set (run via setup.sh)}"

# Cache sudo credentials up front and keep them alive while the script runs
sudo -v
while true; do sudo -n true; sleep 30; kill -0 "$$" || exit; done 2>/dev/null &

# --- apt packages (Brewfile-equivalent, Linux-only subset) -----------------
APT_PKGS=(
    aria2
    build-essential
    clojure
    cmake
    default-jdk
    exiftool
    ffmpeg
    fzf
    gcc
    gh
    ghostscript
    git
    gnupg
    graphviz
    htop
    imagemagick
    jpegoptim
    libheif1
    libraw-bin
    librsvg2-bin
    llvm
    ncdu
    neovim
    nodejs
    npm
    pkg-config
    ruby
    speedtest-cli
    stow
    tailscale
    tcptraceroute
    tealdeer
    tree
    wget
    zsh
)

echo "Updating apt and installing packages..."
sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${APT_PKGS[@]}"

# --- zellij (no official apt; pull latest musl release from GitHub) -------
if ! command -v zellij &>/dev/null; then
    echo "Installing zellij from GitHub releases..."
    case "$(uname -m)" in
        x86_64)        ZJ_TARGET="x86_64-unknown-linux-musl" ;;
        aarch64|arm64) ZJ_TARGET="aarch64-unknown-linux-musl" ;;
        *) echo "Unsupported arch for zellij: $(uname -m)"; ZJ_TARGET="" ;;
    esac
    if [ -n "$ZJ_TARGET" ]; then
        ZJ_TMP=$(mktemp -d)
        curl -fsSL "https://github.com/zellij-org/zellij/releases/latest/download/zellij-${ZJ_TARGET}.tar.gz" \
            | tar -xz -C "$ZJ_TMP"
        sudo install -m 755 "$ZJ_TMP/zellij" /usr/local/bin/zellij
        rm -rf "$ZJ_TMP"
    fi
else
    echo "zellij already installed."
fi

# --- uv (astral installer, lands in ~/.local/bin) -------------------------
if command -v uv &>/dev/null || [ -x "$HOME/.local/bin/uv" ]; then
    echo "uv already installed."
else
    echo "Installing uv via astral installer..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# --- hand off to common steps (zdotdir, .zshenv, stow, chsh) --------------
export ZSH_BIN="$(command -v zsh)"
source "$DOTFILES_DIR/scripts/common.sh"

echo
echo "Done. Open a new terminal (or run 'exec zsh') to load the new shell."
