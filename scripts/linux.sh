#!/usr/bin/env bash
# Linux/Ubuntu setup. Invoke via the top-level setup.sh (which exports
# DOTFILES_DIR). Runs as the user; sudo prompts inline for apt + chsh.
#
# DRY_RUN=1 to validate without mutating filesystem state (used by CI).

set -euo pipefail

: "${DOTFILES_DIR:?DOTFILES_DIR must be set (run via setup.sh)}"
DRY_RUN="${DRY_RUN:-0}"
export DRY_RUN

if [ "$DRY_RUN" = "1" ]; then
    echo "=== DRY RUN MODE ==="
fi

# Cache sudo credentials up front and keep them alive while the script runs
sudo -v
while true; do sudo -n true; sleep 30; kill -0 "$$" || exit; done 2>/dev/null &

# --- Tailscale apt repo (bootstrap on fresh systems; needed even for ------
# dry-run so that apt-get install --dry-run can resolve the package). -------
if ! apt-cache policy tailscale 2>/dev/null | grep -q 'Candidate:'; then
    echo "Adding Tailscale apt repo..."
    codename=$(lsb_release -cs)
    curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.noarmor.gpg" \
        | sudo tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null
    curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/${codename}.tailscale-keyring.list" \
        | sudo tee /etc/apt/sources.list.d/tailscale.list >/dev/null
fi

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

echo "Updating apt..."
sudo apt-get update

# Some packages aren't in every supported LTS apt repo (e.g. tealdeer landed
# in noble). Prune anything without a real Candidate so the install step
# doesn't fail on older releases.
skipped=()
for i in "${!APT_PKGS[@]}"; do
    pkg="${APT_PKGS[$i]}"
    if ! apt-cache policy "$pkg" 2>/dev/null | grep -q 'Candidate: [^(]'; then
        skipped+=("$pkg")
        unset 'APT_PKGS[i]'
    fi
done
APT_PKGS=("${APT_PKGS[@]}")
if [ ${#skipped[@]} -gt 0 ]; then
    echo "Skipping (no apt candidate on $(lsb_release -cs)): ${skipped[*]}"
fi

if [ "$DRY_RUN" = "1" ]; then
    echo "Validating ${#APT_PKGS[@]} apt packages (dry-run)..."
    sudo apt-get install --dry-run -y "${APT_PKGS[@]}" >/dev/null
    echo "All ${#APT_PKGS[@]} apt packages resolved successfully."
else
    echo "Installing apt packages..."
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${APT_PKGS[@]}"
fi

# --- zellij (no official apt; pull latest musl release from GitHub) -------
case "$(uname -m)" in
    x86_64)        ZJ_TARGET="x86_64-unknown-linux-musl" ;;
    aarch64|arm64) ZJ_TARGET="aarch64-unknown-linux-musl" ;;
    *) echo "Unsupported arch for zellij: $(uname -m)"; ZJ_TARGET="" ;;
esac
ZJ_URL="https://github.com/zellij-org/zellij/releases/latest/download/zellij-${ZJ_TARGET}.tar.gz"

if command -v zellij &>/dev/null; then
    echo "zellij already installed."
elif [ -z "$ZJ_TARGET" ]; then
    : # unsupported arch, already warned
elif [ "$DRY_RUN" = "1" ]; then
    echo "Validating zellij release URL (dry-run)..."
    curl -fsSLI -o /dev/null "$ZJ_URL"
    echo "[dry-run] would install zellij from $ZJ_URL"
else
    echo "Installing zellij from GitHub releases..."
    ZJ_TMP=$(mktemp -d)
    curl -fsSL "$ZJ_URL" | tar -xz -C "$ZJ_TMP"
    sudo install -m 755 "$ZJ_TMP/zellij" /usr/local/bin/zellij
    rm -rf "$ZJ_TMP"
fi

# --- uv (astral installer, lands in ~/.local/bin) -------------------------
if command -v uv &>/dev/null || [ -x "$HOME/.local/bin/uv" ]; then
    echo "uv already installed."
elif [ "$DRY_RUN" = "1" ]; then
    echo "Validating uv installer URL (dry-run)..."
    curl -fsSLI -o /dev/null https://astral.sh/uv/install.sh
    echo "[dry-run] would install uv via https://astral.sh/uv/install.sh"
else
    echo "Installing uv via astral installer..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# --- hand off to common steps (zdotdir, .zshenv, stow, chsh) --------------
# In dry-run, zsh hasn't actually been installed — fall back to its
# eventual path so common.sh's ZSH_BIN guard doesn't fail.
export ZSH_BIN="$(command -v zsh || echo /usr/bin/zsh)"
source "$DOTFILES_DIR/scripts/common.sh"

echo
if [ "$DRY_RUN" = "1" ]; then
    echo "Dry-run finished without errors."
else
    echo "Done. Open a new terminal (or run 'exec zsh') to load the new shell."
fi
