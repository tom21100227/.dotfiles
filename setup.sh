#!/bin/bash
# This script sets up the zsh configuration and installs packages from the Brewfile.

# TODO: Review and set these variables as needed.
# BREWFILE_PATH="" # This will be set automatically by SCRIPT_DIR/Brewfile
# SYS_USERNAME="" # This can be derived from $USER or $HOME
# DEVICE_OWNER="" # e.g., "John Doe"
# DEVICE_OWNER_EMAIL="" # e.g., "john.doe@example.com"

# Get the directory of the script
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
ITERM_SETTINGS_DIR="$SCRIPT_DIR/iterm2"
ISTAT_MENUS_SETTINGS="$SCRIPT_DIR/istatmenus/iStat Menus Settings.ismp7"

# Prevent sleeping during script execution, as long as the machine is on AC power
caffeinate -s -w $ &

# Attempt to list the contents of a directory that requires full disk access
check_full_disk_access() {
  if ls /Library/Application\ Support/com.apple.TCC &>/dev/null; then
    return 0
  else
    return 1
  fi
}

# Check for full disk access
if check_full_disk_access; then
  echo "Full disk access is granted - installation will proceed..."
else
  echo "Full disk access is not granted. Please grant full disk access to the terminal and try again! To do so: System Settings -> Privacy & Security -> Full Disk Access -> Enable/add Terminal.app"
  exit 1
fi

# Ask for the administrator password upfront
sudo -v

# Update existing `sudo` timestamp until script has finished
while true; do sudo -n true; sleep 30; kill -0 "$$" || exit; done 2>/dev/null &

echo "Enable TouchID for sudo"
sed -e 's/^#auth/auth/' /etc/pam.d/sudo_local.template | sudo tee /etc/pam.d/sudo_local

echo "Closing any open System Settings windows so settings are not overwritten..."
osascript -e 'tell application "System Preferences" to quit'

echo "Closing any open services that we're about to change..."
killall Dock
killall SystemUIServer

echo "Closing any open apps that we're about to change..."
apps=("Finder" "Safari" "TextEdit" "Music" "Messages" "Photos" "Transmission" "Hazel" "QLMarkdown" "HandBrake" "IINA" "VLC" "iTerm" "ProtonVPN" "Keka" "Downie 4" "The Unarchiver" "UTC Time" "Pure Paste")

for app in "${apps[@]}"; do
    if pgrep -x "$app" > /dev/null; then
        killall "$app" 2>/dev/null
        echo "$app closed."
    else
        echo "$app" is not running, not closing.
    fi
done

# --- Xcode Command Line Tools ---
echo "Checking for Xcode Command Line Tools..."
if ! xcode-select -p &> /dev/null; then
  echo "Xcode Command Line Tools not found. Installing..."
  xcode-select --install
else
  echo "Xcode Command Line Tools are already installed."
fi

echo "Wait for the xcode-select GUI installer and press enter. XCode command-line tools are required"
sudo xcodebuild -license accept

# Loop until the tools are successfully installed and the license is accepted
while :
do
    # Check if Xcode command-line tools are installed
    if ! xcode-select -p &> /dev/null; then
        echo "Xcode command-line tools not installed yet. Waiting..."
        sleep 5  # Wait for 5 seconds before checking again
    else
        echo "Xcode command-line tools installed!"

        # Check if the license has been accepted
        if sudo xcodebuild -license status | grep -q "not accepted"; then
            echo "Xcode license not accepted. Please accept the license..."
            sudo xcodebuild -license accept
        else
            echo "Xcode license accepted!"
            break  # Exit the loop since tools are installed and license accepted
        fi
    fi
done

# echo "Clearing existing .DS_Store files..."
# sudo find / -name ".DS_Store" -print -delete &

# --- Homebrew Installation ---
echo "Checking for Homebrew..."
if ! command -v brew &> /dev/null
then
    echo "Homebrew not found. Installing..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/opt/homebrew/bin/brew shellenv)"
else
    echo "Homebrew is already installed."
fi

# --- Brew Bundle Installation ---
echo "Installing packages from Brewfile..."
brew bundle install -v --file="$SCRIPT_DIR/Brewfile"

sleep 3

echo "Make Homebrew's version of zsh the default shell"
# Append brew's zsh install to the list of acceptable shells for chpass(1)
if ! fgrep -q '/opt/homebrew/bin/zsh' /etc/shells; then
  echo '/opt/homebrew/bin/zsh' | sudo tee -a /etc/shells
fi
# Change default shell to brew's zsh
chsh -s /opt/homebrew/bin/zsh

sleep 3

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

# Terminal needs to be restarted to launch from new zsh, but not necessary for the remainder of this script

sleep 1
echo "Part 1 of setup complete, beginning part 2 in 3 seconds..."
sleep 1
echo "3..."
sleep 1
echo "2..."
sleep 1
echo "1..."
sleep 1

echo "Set up .nanorc..."
rm -rf "$HOME/.nanorc"
echo 'set linenumbers' >> "$HOME/.nanorc"
echo 'include "'""$(brew --cellar nano)""'/opt/homebrew/Cellar/nano/*/share/nano/*.nanorc"' >> "$HOME/.nanorc"

################################################################################
# Time and date
################################################################################

echo "Use 24 Hour Time system-wide"
defaults write -g AppleICUForce24HourTime -bool true
defaults write com.apple.menuextra.clock Show24Hour -bool true

echo "Turn on seconds in the menu bar clock"
defaults write com.apple.menuextra.clock ShowSeconds -bool true

echo "Flash separators between HH:MM:SS"
defaults write com.apple.menuextra.clock FlashDateSeparators -bool true

echo "Set the first day of the week to Monday"
defaults write -g AppleFirstWeekday -dict gregorian -int 2

echo "Set date format to ISO-8601"
defaults write -g AppleICUDateFormatStrings -dict-add 1 "y-MM-dd"

echo "Always show the date in the menu bar"
defaults write com.apple.menuextra.clock ShowDate -int 1

################################################################################
# Misc
################################################################################

echo "Expand the save pane by default"
defaults write -g NSNavPanelExpandedStateForSaveMode -bool true
defaults write -g NSNavPanelExpandedStateForSaveMode2 -bool true

echo "Expand the print pane by default"
defaults write -g PMPrintingExpandedStateForPrint -bool true
defaults write -g PMPrintingExpandedStateForPrint2 -bool true
ick -string "None"

echo "Automatically quit printer app once the print jobs complete"
defaults write com.apple.print.PrintingPrefs "Quit When Finished" -bool true

echo "Never prefer tabs when opening documents"
defaults write -g AppleWindowTabbingMode -string "manual"

################################################################################
# Appearance
################################################################################

echo "Click in the scrollbar to jump to the spot that's clicked"
defaults write -g AppleScrollerPagingBehavior -bool true

echo "Always show scroll bars when they're available"
defaults write -g AppleShowScrollBars -string "Always"

echo "Disable the crash reporter"
defaults write com.apple.CrashReporter DialogType -string "none"

################################################################################
# Battery
################################################################################

# Not displaying battery percentage because I use iStat

echo "Uncheck: Slightly dim the display on battery"
sudo pmset -b lessbright 0

################################################################################
# Menu bar / Control Center
################################################################################

echo "Show Display in menu bar when active"
defaults -currentHost write com.apple.controlcenter Display -int 2

echo "Sound: Don't show in menu bar"
defaults -currentHost write com.apple.controlcenter Sound -int 8

echo "Now Playing: Don't show in menu bar"
defaults -currentHost write com.apple.controlcenter NowPlaying -int 8

echo "Battery: Don't show in menu bar"
defaults -currentHost write com.apple.controlcenter Battery -int 8

echo "Hide Spotlight in the menu bar"
defaults -currentHost write com.apple.Spotlight MenuItemHidden -int 1

################################################################################
# Dock
################################################################################

echo "Disable gaps when snapping window"
defaults write com.apple.WindowManager AppWindowGroupingBehavior -int 1
defaults write com.apple.WindowManager AutoHide -bool false
defaults write com.apple.WindowManager EnableTiledWindowMargins -bool false
defaults write com.apple.WindowManager HideDesktop -bool true
defaults write com.apple.WindowManager StageManagerHideWidgets -bool false
defaults write com.apple.WindowManager StandardHideWidgets -bool false

# Hot Corners
echo "Set bottom right corner of screen to show Mission Control".
defaults write com.apple.dock "wvous-br-corner" -int 2
defaults write com.apple.dock "wvous-br-modifier" -int 0

echo "Set top right corner of screen to show Notification Center"
defaults write com.apple.dock "wvous-tr-corner" -int 12
defaults write com.apple.dock "wvous-tr-modifier" -int 0

################################################################################
# Screenshots
################################################################################

echo "Disable date in screenshot filenames"
defaults write com.apple.screencapture include-date -bool false

################################################################################
# Finder / files
################################################################################

echo "Explicitly show the ~/Library directory"
chflags nohidden "${HOME}/Library"

echo "Remove macOS's default /Public/Drop Box"
sudo rm -rf "${HOME}/Public/Drop Box"

echo "Add an iCloud shortcut in home root"
ln -f -s ~/Library/Mobile\ Documents/com~apple~CloudDocs ~/iCloud

echo "Display all file extensions in Finder"
defaults write -g AppleShowAllExtensions -bool true

echo "Display hidden files in Finder"
defaults write com.apple.finder AppleShowAllFiles -bool true

echo "Display status bar in Finder"
defaults write com.apple.finder ShowStatusBar -bool true

echo "Display path bar above status bar in Finder"
defaults write com.apple.finder ShowPathbar -bool true

echo "Use list view by default"
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"

echo "Sort folders on top of other files"
defaults write com.apple.finder _FXSortFoldersFirst -bool true

echo "Automatically empty bin after 30 days"
defaults write com.apple.finder FXRemoveOldTrashItems -bool true

echo "Disable the trash emptying warning"
defaults write com.apple.finder WarnOnEmptyTrash -bool false

echo "Disable warning popup when changing file extensions"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

echo "Disable warning popup when deleting from iCloud Drive"
defaults write com.apple.finder FXEnableRemoveFromICloudDriveWarning -bool false

echo "Disable .DS_Store file writing on network volumes and removable media"
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

echo "Don't prompt to use new disks for TimeMachine backups"
defaults write com.apple.TimeMachine DoNotOfferNewDisksForBackup -bool true

echo "Delete default Finder tags"
defaults delete com.apple.finder FavoriteTagNames

echo "Set default Finder window to home directory"
defaults write com.apple.finder NewWindowTarget -string "PfHm"

echo "Disable opening new tab behavior by Finder"
defaults write com.apple.finder FinderSpawnTab -bool false

################################################################################
# Keyboard
################################################################################

echo "Set a fast keyboard repeat rate"
defaults write -g KeyRepeat -int 2
defaults write -g InitialKeyRepeat -int 15

echo "Turn off auto capitalization"
defaults write -g NSAutomaticCapitalizationEnabled -bool false

echo "Disable smart dashes"
defaults write -g NSAutomaticDashSubstitutionEnabled -bool false

echo "Disable automatic period substitution"
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false

echo "Disable smart quotes"
defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false

echo "Repeats pressed key as long as it is held down"
defaults write -g ApplePressAndHoldEnabled -bool false

echo "Turn on Keyboard navigation"
defaults write -g AppleKeyboardUIMode -int 2

################################################################################
# Mouse / Trackpad
################################################################################


echo "Set trackpad speed"
defaults write -g com.apple.trackpad.scaling -float 1

echo "Enable trackpad tap to click"
defaults -currentHost write -g com.apple.mouse.tapBehavior -int 1

defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.AppleBluetoothMultitouchTrackpad Clicking -bool true

echo "Make trackpad click sensitivity the lowest setting"
defaults write com.apple.AppleMultitouchTrackpad FirstClickThreshold -int 0
defaults write com.apple.AppleMultitouchTrackpad SecondClickThreshold -int 0

echo "Set pointer size to 2.0 (default is 1.0). A logout/login or restart may be required for this to take effect."
defaults write com.apple.universalaccess mouseDriverCursorSize -float 2.0

################################################################################
# Mouse / Trackpad
################################################################################

echo "Set trackpad speed"
defaults write -g com.apple.trackpad.scaling -float 1

echo "Enable trackpad tap to click"
defaults -currentHost write -g com.apple.mouse.tapBehavior -int 1

defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.AppleBluetoothMultitouchTrackpad Clicking -bool true

echo "Make trackpad click sensitivity the lowest setting"
defaults write com.apple.AppleMultitouchTrackpad FirstClickThreshold -int 0
defaults write com.apple.AppleMultitouchTrackpad SecondClickThreshold -int 0

echo "Set pointer size to 2.0 (default is 1.0). A logout/login or restart may be required for this to take effect."
defaults write com.apple.universalaccess mouseDriverCursorSize -float 2.0

echo "Disable mouse acceleration (may require logout/login or restart)"
defaults write .GlobalPreferences com.apple.mouse.scaling -1
defaults write NSGlobalDomain com.apple.mouse.linear -bool YES

################################################################################
# TextEdit
################################################################################

echo "Disable RichText in TextEdit by default"
defaults write com.apple.TextEdit RichText -bool false

echo "Open and save files as UTF-8 in TextEdit"
defaults write com.apple.TextEdit PlainTextEncoding -int 4
defaults write com.apple.TextEdit PlainTextEncodingForWrite -int 4

################################################################################
# App Store
################################################################################

echo "Download newly available updates in background of App Store"
defaults write com.apple.SoftwareUpdate AutomaticDownload -int 1

echo "Turn off prompting to leave reviews/rate apps"
defaults write com.apple.AppStore InAppReviewEnabled -bool false

################################################################################
# Safari
################################################################################

echo "Show full URL in Safari menu bar"
defaults write com.apple.safari ShowFullURLInSmartSearchField -bool true

echo "Set DuckDuckGo as the default search engine in Safari"
defaults write -g NSPreferredWebServices -dict-add NSWebServicesProviderWebSearch '{ NSDefaultDisplayName = DuckDuckGo; NSProviderIdentifier = "com.duckduckgo"; }'
defaults write com.apple.Safari SearchProviderShortName -string "DuckDuckGo"

echo "Disable top hit preloading in Safari"
defaults write com.apple.Safari PreloadTopHit -bool false

echo "Turn off Autofill in Safari / don't remember passwords"
defaults write com.apple.Safari AutoFillFromAddressBook -bool false
defaults write com.apple.Safari AutoFillMiscellaneousForms -bool false
defaults write com.apple.Safari AutoFillPasswords -bool false

echo "Turn off opening downloads automatically in Safari"
defaults write com.apple.Safari AutoOpenDownloads -bool false

echo "Delete downloads from the list in Safari after successful download"
defaults write com.apple.Safari DownloadsClearingPolicy -int 2

echo "Clear history after 30 days"
defaults write com.apple.Safari HistoryAgeInDaysLimit -int 30

echo "Make the Safari homepage blank"
defaults write com.apple.Safari HomePage -string "about:blank"

echo "Don't show favorites in Safari"
defaults write com.apple.Safari ShowFavorites -bool false

echo "Don't show search suggestions in Safari"
defaults write com.apple.Safari SuppressSearchSuggestions -bool true

echo "Don't let websites ask if they can send push notifications in Safari"
defaults write com.apple.Safari CanPromptForPushNotifications -bool false

echo "Tell sites to not track in Safari"
defaults write com.apple.Safari SendDoNotTrackHTTPHeader -bool true

echo "Disable Safari's thumbnail cache for History and Top Sites"
defaults write com.apple.Safari DebugSnapshotsUpdatePolicy -int 2

echo "Don't open downloaded files automatically"
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

################################################################################
# Photos
################################################################################

echo "Exclude location when sharing photos"
defaults write com.apple.photos.shareddefaults ExcludeLocationWhenSharing -bool true

echo "Prevent Photos from opening when a new device is plugged in"
defaults -currentHost write com.apple.ImageCapture disableHotPlug -bool true

################################################################################
# Messages
################################################################################

echo "Turn off read receipts"
defaults write com.apple.imagent Setting.EnableReadReceipts -bool false

################################################################################
# Calendar
################################################################################

echo "Show week numbers in Calendar"
defaults write com.apple.iCal "Show Week Numbers" -bool true

echo "Turn on timezone support in Calendar"
defaults write com.apple.iCal "TimeZone support enabled" -bool true

defaults write com.apple.iCal privacyPaneHasBeenAcknowledgedVersion -int 4

################################################################################
# Music
################################################################################

echo "Disable song change notifications in Music.app"
defaults write com.apple.Music userWantsPlaybackNotifications -bool false

echo "Turn on Music.app cloud library"
defaults write com.apple.airplay cloudLibraryIsOn -bool true

################################################################################
# Archive Utility
################################################################################

echo "Move archives to trash after extraction"
defaults write com.apple.archiveutility "dearchive-into" -string "."
defaults write com.apple.archiveutility "dearchive-move-after" -string "~/.Trash"
defaults write com.apple.archiveutility "dearchive-recursively" -bool true

################################################################################
# Activity Monitor
#
# More @ https://github.com/hjuutilainen/dotfiles/blob/master/bin/macos-user-defaults.sh
################################################################################

echo "Show all processes in Activity Monitor"
defaults write com.apple.ActivityMonitor ShowCategory -int 100

echo "Sort by CPU usage in Activity Monitor"
defaults write com.apple.ActivityMonitor SortColumn -string "CPUUsage"
defaults write com.apple.ActivityMonitor SortDirection -int 0

################################################################################
# Notes
################################################################################

echo "Skip initial welcome screen"
defaults write com.apple.Notes hasShownWelcomeScreen -bool true

echo "Don't show auto rearranging note checklist warning"
defaults write com.apple.Notes AutoSortChecklistAlertShown -bool true

################################################################################
# Terminal / iTerm2
################################################################################

echo "Only use UTF-8 in Terminal.app"
defaults write com.apple.terminal StringEncodings -array 4

echo "Don't display the annoying prompt when quitting iTerm"
defaults write com.googlecode.iterm2 PromptOnQuit -bool false

echo "Configure iTerm2 to read preferences from iCloud"
defaults write com.googlecode.iterm2 PrefsCustomFolder -string "$ITERM_SETTINGS_DIR"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true

################################################################################
# The Unarchiver
################################################################################

defaults write com.macpaw.site.theunarchiver deleteExtractedArchive -bool true

################################################################################
# UTC Time
################################################################################

defaults write com.sindresorhus.UTC-Time showUTCText -bool false

################################################################################
# Tracking
################################################################################

echo "Tell IINA, VLC, Hazel, The Unarchiver, ProtonVPN, QLMarkdown, HandBrake, and iTerm2 to not send anonymous system profile"
# TODO: Review - Disables anonymous system profile sending for various applications.
defaults write com.colliderli.iina SUSendProfileInfo -bool false
defaults write org.videolan.vlc SUSendProfileInfo -bool false
defaults write com.googlecode.iterm2 SUSendProfileInfo -bool false

################################################################################
# Updates
################################################################################

echo "Enable automatic update check in App Store"
defaults write com.apple.SoftwareUpdate AutomaticCheckEnabled -bool true

echo "Check for software updates daily in App Store, not just once per week"
defaults write com.apple.SoftwareUpdate ScheduleFrequency -int 1

echo "Turn on app auto-update in App Store"
defaults write com.apple.commerce AutoUpdate -bool true

echo "Update extensions automatically in Safari"
defaults write com.apple.Safari InstallExtensionUpdatesAutomatically -bool true

echo "Tell IINA, VLC, Hazel, The Unarchiver, QLMarkdown, HandBrake, Downie 4, Keka, and iTerm2 to check for updates automatically"
defaults write com.colliderli.iina SUEnableAutomaticChecks -bool true
defaults write org.videolan.vlc SUEnableAutomaticChecks -bool true
defaults write com.googlecode.iterm2 SUEnableAutomaticChecks -bool true

echo "Turn on auto-update in IINA, VLC, ProtonVPN, QLMarkdown, Downie 4, Keka, and iTerm2"
defaults write com.colliderli.iina SUAutomaticallyUpdate -bool true
defaults write org.videolan.vlc SUAutomaticallyUpdate -bool true
defaults write com.googlecode.iterm2 SUAutomaticallyUpdate -bool true

echo "Disable guest sign-in from login screen"
sudo defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false

echo "Disable guest access to file shares over AF"
sudo defaults write /Library/Preferences/SystemConfiguration/com.apple.smb.server AllowGuestAccess -bool false

echo "Disable guest access to file shares over SMB"
sudo defaults write /Library/Preferences/com.apple.AppleFileServer guestAccess -bool false

################################################################################
# Zoom
################################################################################

echo "Disable screen recording prompt that appears each month"
defaults write ~/Library/Group\ Containers/group.com.apple.replayd/ScreenCaptureApprovals.plist "/Applications/zoom.us.app/Contents/MacOS/zoom.us" -date "3024-09-21 12:40:36 +0000"

################################################################################
# Finalize
################################################################################

echo "Setting up dock apps layout..."
# Clear existing
dockutil --remove all
dockutil --add "/Applications/1Password.app"
dockutil --add "/Applications/iTerm.app"
dockutil --add "/Applications/Safari.app"
dockutil --add "/Applications/Firefox.app"
dockutil --add "/Applications/Arc.app"
dockutil --add "/Applications/Messages.app"
dockutil --add "/Applications/Slack.app"
dockutil --add "/Applications/Mail.app"
dockutil --add "/Applications/Reminders.app"
dockutil --add "/Applications/Notes.app"
dockutil --add "/Applications/Music.app"
dockutil --add "/Applications/Visual Studio Code.app"
dockutil --add "/Applications/Spotify.app"

dockutil --add "$HOME/Downloads" --view grid --display stack


# Restart QuickLook
qlmanage -r

# Restart affected services
killall Dock SystemUIServer Finder Safari TextEdit Music Messages Photos Transmission

# If needed for Adobe CC/Minecraft/etc.
softwareupdate --install-rosetta --agree-to-license

echo "Setup complete. Please start a new zsh session for changes to take effect."

read -p "Do you want to proceed with further setup (e.g., logging into GitHub Desktop and 1Password)? (y/N) " -n 1 -r
echo    # (optional) move to a new line
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "Opening GitHub Desktop, 1Password, iStatMenus"
    open -a "GitHub Desktop"
    open -a "1Password"
    open -a $ISTAT_MENUS_SETTINGS
else
    echo "Skipping further setup."
fi
