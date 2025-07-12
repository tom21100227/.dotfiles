#!/bin/bash
# This script sets up the zsh configuration and installs packages from the Brewfile.

# --- Xcode Command Line Tools ---
echo "Checking for Xcode Command Line Tools..."
if ! xcode-select -p &> /dev/null; then
  echo "Xcode Command Line Tools not found. Installing..."
  xcode-select --install
else
  echo "Xcode Command Line Tools are already installed."
fi

# --- Homebrew Installation ---
echo "Checking for Homebrew..."
if ! command -v brew &> /dev/null
then
    echo "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
    echo "Homebrew is already installed."
fi

# --- Brew Bundle Installation ---
# Get the directory of the script to locate the Brewfile
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
echo "Installing packages from Brewfile..."
brew bundle --file="$SCRIPT_DIR/Brewfile"

# --- System Preferences ---
echo "Applying macOS system preferences..."

# Show all file extensions in Finder
defaults write -g AppleShowAllExtensions -bool true

# Show hidden files in Finder
defaults write com.apple.finder AppleShowAllFiles -bool true

# Show the path bar in Finder
defaults write com.apple.finder ShowPathbar -bool true

# Show the status bar in Finder
defaults write com.apple.finder ShowStatusBar -bool true

# Set new Finder windows to open in the home directory
defaults write com.apple.finder NewWindowTarget -string "PfHm"

# Set the preferred view style in Finder to list view
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

# Sort folders before files in Finder
defaults write com.apple.finder _FXSortFoldersFirst -bool true

# Prevent Photos from opening automatically when devices are plugged in
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

# Avoid creating .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Make the Library folder visible in Finder
chflags nohidden ~/Library

# Increase cursor size
defaults write com.apple.universalaccess mouseDriverCursorSize -float 4.0

echo "System preferences applied. Note: Some changes may require a restart or logging out to take effect."

# --- VS Code Settings ---
echo "Setting up VS Code settings..."
VSCODE_SETTINGS_DIR="$HOME/Library/Application Support/Code/User"
VSCODE_SETTINGS_FILE="$VSCODE_SETTINGS_DIR/settings.json"
DOTFILES_VSCODE_SETTINGS="$SCRIPT_DIR/vscode_settings.json"

# Create the VS Code settings directory if it doesn't exist
mkdir -p "$VSCODE_SETTINGS_DIR"

# Back up existing settings.json and create a symlink
if [ -L "$VSCODE_SETTINGS_FILE" ]; then
    echo "VS Code settings already symlinked. Skipping."
else
    if [ -f "$VSCODE_SETTINGS_FILE" ]; then
        mv -f "$VSCODE_SETTINGS_FILE" "$VSCODE_SETTINGS_FILE.bak"
        echo "Backed up existing VS Code settings to settings.json.bak"
    fi
    ln -s "$DOTFILES_VSCODE_SETTINGS" "$VSCODE_SETTINGS_FILE"
    echo "Symlinked VS Code settings."
fi

# --- iTerm2 Configuration ---
echo "Setting up iTerm2 preferences..."
ITERM_SETTINGS_DIR="$SCRIPT_DIR/iterm2_settings"

# Create the iTerm2 settings directory if it doesn't exist
mkdir -p "$ITERM_SETTINGS_DIR"

# Tell iTerm2 to load preferences from the dotfiles directory
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$ITERM_SETTINGS_DIR"

echo "iTerm2 will now load preferences from $ITERM_SETTINGS_DIR."
echo "Please open iTerm2 preferences (Cmd + ,) and make a change to save current settings to this folder."

# --- Conda Configuration ---
echo "Setting up Conda configuration..."
CONDARC_FILE="$HOME/.condarc"
DOTFILES_CONDARC="$SCRIPT_DIR/.condarc"

if [ -L "$CONDARC_FILE" ]; then
    echo ".condarc already symlinked. Skipping."
else
    if [ -f "$CONDARC_FILE" ]; then
        mv -f "$CONDARC_FILE" "$CONDARC_FILE.bak"
        echo "Backed up existing .condarc to .condarc.bak"
    fi
    ln -s "$DOTFILES_CONDARC" "$CONDARC_FILE"
    echo "Symlinked .condarc."
fi

# --- Dock Configuration ---
echo "Adding applications to Dock..."

# Clear existing persistent applications from the Dock (optional, uncomment if you want a clean slate)
# defaults delete com.apple.dock persistent-apps

defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Visual Studio Code.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/iTerm.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'
defaults write com.apple.dock persistent-apps -array-add '<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/Spotify.app</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>'

killall Dock

echo "Applications added to Dock. Dock will restart."

# --- Zsh Configuration ---
# Define the Zsh configuration directory
ZDOTDIR="$HOME/.config/zsh"

# Clone the project if it doesn't exist
if [ -d "$ZDOTDIR" ]; then
    echo "Zsh configuration directory already exists. Skipping clone."
else
    echo "Cloning zsh configuration from https://github.com/tom21100227/zdotdir..."
    git clone https://github.com/tom21100227/zdotdir "$ZDOTDIR"
fi

# Back up existing .zshenv and create a new one to source from the repo
echo "Setting up .zshenv to source the new configuration..."
if [ -f "$HOME/.zshenv" ]; then
    mv -f "$HOME/.zshenv" "$HOME/.zshenv.bak"
    echo "Backed up existing .zshenv to .zshenv.bak"
fi
echo ". "$ZDOTDIR/.zshenv"" > "$HOME/.zshenv"
