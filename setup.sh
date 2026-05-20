#!/usr/bin/env bash
# Dotfiles bootstrap. Detects OS and runs the matching script in scripts/.
# Both platforms expect to be invoked as the user (no leading sudo) — each
# script will prompt for sudo internally where it needs root.
#
# Usage:  bash setup.sh

set -euo pipefail

export DOTFILES_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

case "$(uname -s)" in
    Darwin) exec bash "$DOTFILES_DIR/scripts/macos.sh" ;;
    Linux)  exec bash "$DOTFILES_DIR/scripts/linux.sh" ;;
    *)
        echo "Unsupported OS: $(uname -s)" >&2
        exit 1
        ;;
esac
