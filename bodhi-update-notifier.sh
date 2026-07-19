#!/usr/bin/env bash

# ==============================================================================
# Bodhi Linux Software Update Utility
# A lightweight, background update notifier using Zenity & Terminology
# ==============================================================================

# --- Configuration ---
CHECK_INTERVAL="4h"                 # Interval between update checks (e.g., 30m, 4h, 12h, 1d)
PROGRESS_MODE="terminal"            # Options: "terminal" (recommended, interactive) or "zenity" (progress bar)
LOG_FILE="$HOME/.local/share/bodhi-update-notifier/notifier.log"
LOCK_FILE="/tmp/bodhi-update-notifier.lock"

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

# --- Helper Functions ---

log_message() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] - $message" >> "$LOG_FILE"
}

parse_interval() {
    local val="$1"
    local num="${val%[smhd]}"
    local unit="${val#$num}"
    case "$unit" in
        s|"") echo "$num" ;;
        m) echo $((num * 60)) ;;
        h) echo $((num * 3600)) ;;
        d) echo $((num * 86400)) ;;
        *) echo "$val" ;; # Fallback to literal seconds
    esac
}

check_internet() {
    # Check internet connection by pinging Google Public DNS
    ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1
}

find_terminal() {
    # Preferred order of terminal emulators (Terminology is default in Bodhi/Moksha)
    for term in terminology x-terminal-emulator xterm kitty alacritty gnome-terminal konsole xfce4-terminal mate-terminal; do
        if command -v "$term" >/dev/null 2>&1; then
            echo "$term"
            return 0
        fi
    done
    return 1
}

# --- Lock Mechanism (Single Instance Control) ---
if [ -f "$LOCK_FILE" ]; then
    PID=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        log_message "INFO" "Notifier is already running (PID: $PID). Exiting duplicate process."
        exit 0
    fi
fi
echo $$ > "$LOCK_FILE"

cleanup() {
    rm -f "$LOCK_FILE"
    log_message "INFO" "Notifier service stopped."
}
trap cleanup EXIT INT TERM

log_message "INFO" "Bodhi Update Notifier service started. Check interval: $CHECK_INTERVAL"

# Convert interval to seconds
SLEEP_SECONDS=$(parse_interval "$CHECK_INTERVAL")
# Default retry sleep if internet is offline or error occurs
RETRY_SECONDS=300 # 5 minutes

while true; do
    log_message "DEBUG" "Starting update check cycle..."

    # 1. Check Internet Connection
    if ! check_internet; then
        log_message "WARNING" "No internet connection detected. Retrying in 5 minutes..."
        sleep "$RETRY_SECONDS"
        continue
    fi

    # 2. Try to refresh package list (apt-get update) silently
    log_message "DEBUG" "Refreshing package indexes..."
    if sudo -n apt-get update >/dev/null 2>&1; then
        log_message "INFO" "Package index refreshed successfully via sudo."
    else
        log_message "INFO" "Silent 'apt-get update' skipped (requires sudo credentials or passwordless config). Using existing cache."
    fi

    # 3. Check for upgradable packages
    log_message "DEBUG" "Checking for upgradable packages..."
    UPGRADABLE_COUNT=$(apt-get -s upgrade 2>/dev/null | grep -E '^Inst ' | wc -l)

    if [ "$UPGRADABLE_COUNT" -gt 0 ]; then
        log_message "INFO" "Updates found! Upgradable packages count: $UPGRADABLE_COUNT"
        
        # Ensure DISPLAY is set before attempting GUI prompt
        if [ -z "$DISPLAY" ]; then
            export DISPLAY=":0.0"
        fi
        
        # 4. Display graphical notification dialog
        # Using Zenity with formatting and system icons
        if zenity --question \
            --title="Bodhi Update Utility" \
            --text="<span font='11' weight='bold'>System Updates Available</span>\n\nThere are <b>$UPGRADABLE_COUNT</b> software updates ready for your Bodhi Linux system.\n\nWould you like to install them now?" \
            --icon-name="software-update-available" \
            --ok-label="Install Now" \
            --cancel-label="Remind Me Later" \
            --width=400 >/dev/null 2>&1; then
            
            # User clicked "Install Now"
            log_message "INFO" "User consented to install updates. Mode: $PROGRESS_MODE"
            
            if [ "$PROGRESS_MODE" = "terminal" ]; then
                # Interactive Terminal Mode
                TERM_EMU=$(find_terminal)
                if [ -n "$TERM_EMU" ]; then
                    log_message "INFO" "Launching terminal: $TERM_EMU"
                    
                    # We wrap the update process inside a shell script block, with clean outputs
                    UPGRADE_CMD="echo '=== BODHI SOFTWARE UPDATE ==='; echo; sudo apt-get upgrade -y && sudo apt-get autoremove -y; echo; echo '=== Update Finished! ==='; echo 'Press [Enter] to close this window.'; read -r"
                    
                    if [ "$TERM_EMU" = "terminology" ]; then
                        # Terminology has a special -H/--hold flag, but adding read -r inside cmd makes it doubly safe
                        terminology -T "Bodhi System Update" --hold -e bash -c "$UPGRADE_CMD" &
                    elif [ "$TERM_EMU" = "x-terminal-emulator" ]; then
                        x-terminal-emulator -e bash -c "$UPGRADE_CMD" &
                    else
                        "$TERM_EMU" -e bash -c "$UPGRADE_CMD" &
                    fi
                    
                    # Sleep slightly to allow the terminal to launch and ask for sudo password before checking again
                    sleep 15
                else
                    log_message "ERROR" "No suitable terminal emulator found!"
                    zenity --error --title="Bodhi Update Utility" --text="Could not open terminal emulator for the update." --width=350
                fi
            elif [ "$PROGRESS_MODE" = "zenity" ]; then
                # Graphical Progress Mode using pkexec (requires polkit password popup)
                log_message "INFO" "Launching graphical progress update via pkexec..."
                
                # Check if pkexec is installed
                if command -v pkexec >/dev/null 2>&1; then
                    # We run update using pkexec, set DEBIAN_FRONTEND=noninteractive to prevent blocking prompts,
                    # and pipe to a Zenity progress bar.
                    (
                        pkexec env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
                        pkexec env DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
                    ) 2>&1 | zenity --progress \
                        --title="Bodhi System Update" \
                        --text="Installing system updates... Please do not close." \
                        --pulsate \
                        --auto-close \
                        --width=450
                        
                    # Capture the exit code of the upgrade pipeline
                    PISTATUS=${PIPESTATUS[0]}
                    if [ "$PISTATUS" -eq 0 ]; then
                        log_message "INFO" "Updates installed successfully via graphical progress."
                        zenity --info --title="Bodhi Update Utility" --text="System updates installed successfully." --width=300
                    else
                        log_message "ERROR" "Graphical upgrade failed or was cancelled. Exit code: $PISTATUS"
                        zenity --error --title="Bodhi Update Utility" --text="Update failed or was cancelled. Please check log for details." --width=350
                    fi
                else
                    log_message "ERROR" "pkexec not found, cannot run graphical progress mode!"
                    zenity --error --title="Bodhi Update Utility" --text="Authentication agent (pkexec) not found." --width=350
                fi
            fi
        else
            log_message "INFO" "User postponed updates."
        fi
    else
        log_message "DEBUG" "No updates available."
    fi

    # Sleep until next check
    log_message "DEBUG" "Sleeping for $CHECK_INTERVAL ($SLEEP_SECONDS seconds)..."
    sleep "$SLEEP_SECONDS"
done
