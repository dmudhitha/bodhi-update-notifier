#!/usr/bin/env bash

# ==============================================================================
# Bodhi Linux Software Update Utility
# A lightweight, background update notifier using Zenity & Terminology
# Supports: APT, Flatpak, Snap, Desktop Notifications & System Tray Applet
# Premium Features: Settings GUI, Changelog Viewer, Metered Warnings, Lock Repair, DND
# ==============================================================================

# --- Path Configurations ---
CONFIG_FILE="$HOME/.config/bodhi-update-notifier/config.conf"
LOG_FILE="$HOME/.local/share/bodhi-update-notifier/notifier.log"
LOCK_FILE="/tmp/bodhi-update-notifier-$UID.lock"
UPDATES_LIST_FILE="$HOME/.local/share/bodhi-update-notifier/updates.list"

# Default config variables
CHECK_INTERVAL="4h"
PROGRESS_MODE="terminal"
CHECK_APT="true"
CHECK_FLATPAK="true"
CHECK_SNAP="true"
ENABLE_QUIET_HOURS="false"
QUIET_HOURS_START="21:00"
QUIET_HOURS_END="08:00"
METERED_WARNING="true"
METERED_THRESHOLD_MB="100"
SILENT_AUTO_UPDATE="false"

# Ensure log and config folders exist
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$CONFIG_FILE")"

# --- Helper Functions ---

log_message() {
    local level="$1"
    local message="$2"
    echo "$(date '+%Y-%m-%d %H:%M:%S') [$level] - $message" >> "$LOG_FILE"
}

write_config() {
    cat <<EOF > "$CONFIG_FILE"
CHECK_INTERVAL="$CHECK_INTERVAL"
PROGRESS_MODE="$PROGRESS_MODE"
CHECK_APT="$CHECK_APT"
CHECK_FLATPAK="$CHECK_FLATPAK"
CHECK_SNAP="$CHECK_SNAP"
ENABLE_QUIET_HOURS="$ENABLE_QUIET_HOURS"
QUIET_HOURS_START="$QUIET_HOURS_START"
QUIET_HOURS_END="$QUIET_HOURS_END"
METERED_WARNING="$METERED_WARNING"
METERED_THRESHOLD_MB="$METERED_THRESHOLD_MB"
SILENT_AUTO_UPDATE="$SILENT_AUTO_UPDATE"
EOF
}

load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        while IFS='=' read -r key val; do
            key=$(echo "$key" | xargs 2>/dev/null || echo "$key")
            val=$(echo "$val" | xargs 2>/dev/null | tr -d '"' | tr -d "'" || echo "$val")
            [ -z "$key" ] && continue
            case "$key" in
                CHECK_INTERVAL) CHECK_INTERVAL="$val" ;;
                PROGRESS_MODE) PROGRESS_MODE="$val" ;;
                CHECK_APT) CHECK_APT="$val" ;;
                CHECK_FLATPAK) CHECK_FLATPAK="$val" ;;
                CHECK_SNAP) CHECK_SNAP="$val" ;;
                ENABLE_QUIET_HOURS) ENABLE_QUIET_HOURS="$val" ;;
                QUIET_HOURS_START) QUIET_HOURS_START="$val" ;;
                QUIET_HOURS_END) QUIET_HOURS_END="$val" ;;
                METERED_WARNING) METERED_WARNING="$val" ;;
                METERED_THRESHOLD_MB) METERED_THRESHOLD_MB="$val" ;;
                SILENT_AUTO_UPDATE) SILENT_AUTO_UPDATE="$val" ;;
            esac
        done < "$CONFIG_FILE"
    else
        write_config
    fi
}

load_config

# --- Feature 1: Settings GUI Panel ---
show_settings_gui() {
    if command -v python3 >/dev/null 2>&1 && [ -f "$SCRIPT_DIR/bodhi-update-settings.py" ]; then
        python3 "$SCRIPT_DIR/bodhi-update-settings.py"
    else
        zenity --error --title="Preferences Error" --text="Preferences GUI helper (bodhi-update-settings.py) not found." --width=300 2>/dev/null
    fi
}

# --- Feature 2: Changelog / Release Notes Viewer ---
show_changelog() {
    local source="$1"
    local pkg="$2"
    local temp_changelog="/tmp/bodhi-update-changelog-$UID.txt"
    
    log_message "INFO" "Fetching release notes for $source package: $pkg"
    
    if [ "$source" = "APT" ]; then
        # Try official changelog
        apt-get changelog "$pkg" 2>/dev/null > "$temp_changelog"
        
        # Fallback to apt-cache show for PPA/third-party packages (e.g. VS Code, Chrome)
        if [ $? -ne 0 ] || [ ! -s "$temp_changelog" ]; then
            echo "==================================================" > "$temp_changelog"
            echo "PACKAGE INFORMATION & DESCRIPTION: $pkg" >> "$temp_changelog"
            echo "==================================================" >> "$temp_changelog"
            echo "" >> "$temp_changelog"
            apt-cache show "$pkg" 2>/dev/null >> "$temp_changelog" || echo "No package information available for $pkg." >> "$temp_changelog"
        fi
    elif [ "$source" = "Flatpak" ]; then
        flatpak info "$pkg" 2>/dev/null > "$temp_changelog"
        if [ $? -ne 0 ] || [ ! -s "$temp_changelog" ]; then
            echo "No detailed Flatpak info available for '$pkg'." > "$temp_changelog"
        fi
    elif [ "$source" = "Snap" ]; then
        snap info "$pkg" 2>/dev/null > "$temp_changelog"
        if [ $? -ne 0 ] || [ ! -s "$temp_changelog" ]; then
            echo "No detailed Snap info available for '$pkg'." > "$temp_changelog"
        fi
    fi
    
    zenity --text-info \
        --title="Release Notes / Package Details: $pkg" \
        --filename="$temp_changelog" \
        --width=650 --height=450 \
        --ok-label="Back to List" 2>/dev/null
}

show_details_dialog() {
    if [ ! -f "$UPDATES_LIST_FILE" ] || [ ! -s "$UPDATES_LIST_FILE" ]; then
        zenity --info --title="Bodhi Update Utility" --text="No updates are currently available." --width=300 2>/dev/null
        return 0
    fi
    
    while true; do
        local zenity_args=()
        while IFS='|' read -r source pkg version; do
            if [ -n "$source" ] && [ -n "$pkg" ] && [ -n "$version" ]; then
                zenity_args+=("$source" "$pkg" "$version")
            fi
        done < "$UPDATES_LIST_FILE"

        if [ ${#zenity_args[@]} -eq 0 ]; then
            break
        fi

        local response
        response=$(zenity --list \
            --title="Available System Updates" \
            --text="Select a package and click 'View Release Notes', or double-click a package row:" \
            --column="Repository" --column="Package/App Name" --column="Available Version" \
            "${zenity_args[@]}" \
            --print-column=ALL \
            --ok-label="View Release Notes" \
            --cancel-label="Close" \
            --extra-button="Install Updates" \
            --width=650 --height=400 2>/dev/null)
            
        local exit_status=$?
        
        if [ "$response" = "Install Updates" ]; then
            install_updates
            break
        elif [ $exit_status -eq 0 ]; then
            if [ -n "$response" ]; then
                local sel_source=$(echo "$response" | cut -d'|' -f1)
                local sel_pkg=$(echo "$response" | cut -d'|' -f2)
                show_changelog "$sel_source" "$sel_pkg"
            else
                zenity --info --title="Bodhi Update Utility" --text="Please click to select a package from the list first before viewing release notes." --width=360 2>/dev/null
            fi
        else
            break
        fi
    done
}

# --- Feature 3: Metered connection & size checks ---
is_connection_metered() {
    if command -v nmcli >/dev/null 2>&1; then
        if nmcli -t -f GENERAL.METERED dev show 2>/dev/null | grep -q -i 'yes'; then
            return 0
        fi
    fi
    return 1
}

get_download_size_mb() {
    local size_line=$(apt-get -s upgrade 2>/dev/null | grep -E '^Need to get')
    if [ -n "$size_line" ]; then
        echo "$size_line" | awk '{print $4, $5}'
    else
        echo "0 MB"
    fi
}

get_download_size_val_mb() {
    local size_line=$(apt-get -s upgrade 2>/dev/null | grep -E '^Need to get')
    if [ -n "$size_line" ]; then
        local num=$(echo "$size_line" | awk '{print $4}')
        local unit=$(echo "$size_line" | awk '{print $5}')
        case "$unit" in
            kB|KB) echo "0" ;;
            gB|GB) echo "$(echo "$num * 1024" | bc -l | cut -d. -f1)" ;;
            mB|MB) echo "${num%.*}" ;;
            *) echo "0" ;;
        esac
    else
        echo "0"
    fi
}

# --- Feature 4: Diagnostics and Locks self-healing ---
repair_package_manager() {
    local term_emu=$(find_terminal)
    local cmd="echo '=== BODHI PACKAGE MANAGER REPAIR ==='; echo; echo 'Clearing locks and running self-healing diagnostics...'; sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock; sudo dpkg --configure -a; sudo apt-get install -f; echo; echo '--> Repair sequence completed!'; echo 'Press [Enter] to close this window.'; read -r"
    
    if [ "$term_emu" = "terminology" ]; then
        terminology -T "Bodhi Package Repair" -e bash -c "$cmd" &
    elif [ -n "$term_emu" ]; then
        "$term_emu" -e bash -c "$cmd" &
    else
        zenity --error --title="Repair Failed" --text="No terminal emulator found to run repairs." --width=300 2>/dev/null
    fi
}

# --- Feature 5: Quiet hours (DND) check ---
is_quiet_hours() {
    if [ "$ENABLE_QUIET_HOURS" != "true" ]; then
        return 1
    fi
    
    local current_time=$(date +%H:%M)
    local start="$QUIET_HOURS_START"
    local end="$QUIET_HOURS_END"
    
    if [ "$start" \< "$end" ]; then
        if [ "$current_time" \>= "$start" ] && [ "$current_time" \< "$end" ]; then
            return 0
        fi
    else
        if [ "$current_time" \>= "$start" ] || [ "$current_time" \< "$end" ]; then
            return 0
        fi
    fi
    return 1
}

# --- Standard execution checks ---

parse_interval() {
    local val="$1"
    local num="${val%[smhd]}"
    local unit="${val#$num}"
    case "$unit" in
        s|"") echo "$num" ;;
        m) echo $((num * 60)) ;;
        h) echo $((num * 3600)) ;;
        d) echo $((num * 86400)) ;;
        *) echo "$val" ;;
    esac
}

find_terminal() {
    for term in terminology x-terminal-emulator xterm kitty alacritty gnome-terminal konsole xfce4-terminal mate-terminal; do
        if command -v "$term" >/dev/null 2>&1; then
            echo "$term"
            return 0
        fi
    done
    return 1
}

check_internet() {
    ping -c 1 -W 3 8.8.8.8 >/dev/null 2>&1
}

send_notification() {
    local title="$1"
    local msg="$2"
    if command -v notify-send >/dev/null 2>&1; then
        notify-send -i "software-update-available" "$title" "$msg"
    else
        zenity --notification --window-icon="software-update-available" --text="$title\n$msg" >/dev/null 2>&1 &
    fi
}

# Ensure DISPLAY and XAUTHORITY are exported for GUI & background daemon calls
export DISPLAY="${DISPLAY:-:0.0}"
[ -z "$XAUTHORITY" ] && [ -f "$HOME/.Xauthority" ] && export XAUTHORITY="$HOME/.Xauthority"

install_updates() {
    log_message "INFO" "User initiated update installation. Mode: $PROGRESS_MODE"
    
    # Ensure DISPLAY and XAUTHORITY are set
    export DISPLAY="${DISPLAY:-:0.0}"
    [ -z "$XAUTHORITY" ] && [ -f "$HOME/.Xauthority" ] && export XAUTHORITY="$HOME/.Xauthority"

    if [ "$PROGRESS_MODE" = "terminal" ]; then
        local term_emu=$(find_terminal)
        if [ -n "$term_emu" ]; then
            log_message "INFO" "Launching terminal: $term_emu"
            local runner_script="/tmp/bodhi-upgrade-runner-$UID.sh"
            
            cat <<EOF > "$runner_script"
#!/usr/bin/env bash
echo '=================================================='
echo '       BODHI LINUX SOFTWARE UPDATE MANAGER        '
echo '=================================================='
echo

echo '--> Upgrading system APT packages...'
sudo apt-get upgrade -y && sudo apt-get autoremove -y
echo

if command -v flatpak >/dev/null 2>&1; then
    echo '--> Upgrading Flatpak applications...'
    flatpak update -y
    echo
fi

if command -v snap >/dev/null 2>&1; then
    echo '--> Upgrading Snap applications...'
    sudo snap refresh
    echo
fi

echo '=================================================='
echo '            VERIFYING INSTALLED UPDATES           '
echo '=================================================='
echo '--> Re-checking package repositories...'
REMAIN_COUNT=\$(apt-get -s upgrade 2>/dev/null | grep -E '^Inst ' | wc -l)

if [ "\$REMAIN_COUNT" -eq 0 ]; then
    echo -n "" > "$UPDATES_LIST_FILE"
    echo "✔ All updates were installed successfully with 0 errors! Your system is up to date."
else
    echo "⚠️ Upgrade finished. \$REMAIN_COUNT package(s) still remaining."
fi
echo

if [ -f "$LOCK_FILE" ]; then
    kill -SIGUSR1 \$(cat "$LOCK_FILE" 2>/dev/null) 2>/dev/null || true
fi

echo 'Press [Enter] to close this window.'
read -r
EOF
            chmod +x "$runner_script"
            
            if [ "$term_emu" = "terminology" ]; then
                terminology -T "Bodhi System Update" -e "$runner_script" &
            elif [ "$term_emu" = "x-terminal-emulator" ]; then
                x-terminal-emulator -e "$runner_script" &
            else
                "$term_emu" -e "$runner_script" &
            fi
        else
            log_message "ERROR" "No suitable terminal emulator found!"
            zenity --error --title="Bodhi Update Utility" --text="Could not open terminal emulator for the update." --width=350 2>/dev/null
        fi
    elif [ "$PROGRESS_MODE" = "zenity" ]; then
        log_message "INFO" "Launching graphical progress update via pkexec..."
        if command -v pkexec >/dev/null 2>&1; then
            (
                echo "10" ; echo "# Updating APT packages..."
                pkexec env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
                pkexec env DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
                
                if command -v flatpak >/dev/null 2>&1; then
                    echo "50" ; echo "# Updating Flatpak applications..."
                    flatpak update -y
                fi
                
                if command -v snap >/dev/null 2>&1; then
                    echo "80" ; echo "# Updating Snap applications..."
                    pkexec snap refresh
                fi
                echo "100" ; echo "# Done!"
            ) 2>&1 | zenity --progress \
                --title="Bodhi System Update" \
                --text="Installing system updates... Please do not close." \
                --percentage=0 \
                --auto-close \
                --width=450 2>/dev/null
                
            local pistatus=${PIPESTATUS[0]}
            if [ "$pistatus" -eq 0 ]; then
                log_message "INFO" "Updates installed via Zenity mode. Verifying..."
                local remain_count=$(apt-get -s upgrade 2>/dev/null | grep -E '^Inst ' | wc -l)
                if [ "$remain_count" -eq 0 ]; then
                    log_message "INFO" "Updates installed successfully with 0 remaining."
                    echo -n "" > "$UPDATES_LIST_FILE"
                    zenity --info --title="Bodhi Update Utility" --text="<span font='11' weight='bold'>Update Complete</span>\n\nAll updates were installed successfully without errors! Your system is now up to date." --icon-name="emblem-synchronized" --width=380 2>/dev/null
                else
                    log_message "WARNING" "Updates finished, but $remain_count package(s) remain."
                    zenity --warning --title="Bodhi Update Utility" --text="Updates finished, but <b>$remain_count</b> package(s) could not be upgraded or are held back." --width=380 2>/dev/null
                fi
            else
                log_message "ERROR" "Upgrade failed or was cancelled. Exit code: $pistatus"
                zenity --error --title="Bodhi Update Utility" --text="Update failed or was cancelled. Please check log for details." --width=350 2>/dev/null
            fi
        else
            log_message "ERROR" "pkexec not found, cannot run graphical progress mode!"
            zenity --error --title="Bodhi Update Utility" --text="Authentication agent (pkexec) not found." --width=350 2>/dev/null
        fi
    fi

    # Signal daemon process to reload config / update tray status icon
    local pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill -SIGUSR1 "$pid"
    fi
}

# --- Feature 6: Interactive Manual Check with Progress Bar ---
run_manual_check_gui() {
    log_message "INFO" "Manual GUI update check requested."
    
    (
        echo "10" ; echo "# Checking internet connection..."
        if ! check_internet; then
            echo "# No internet connection detected."
            sleep 2
            exit 1
        fi
        
        echo "30" ; echo "# Refreshing package indexes..."
        if sudo -n apt-get update >/dev/null 2>&1; then
            log_message "INFO" "Package index refreshed via sudo."
        fi
        
        echo "60" ; echo "# Checking APT system updates..."
        local apt_count=0
        local apt_list=""
        if [ "$CHECK_APT" = "true" ]; then
            while read -r line; do
                pkg=$(echo "$line" | awk '{print $2}')
                ver=$(echo "$line" | awk '{print $4}' | sed 's/[(]//g')
                if [ -n "$pkg" ]; then
                    apt_list="${apt_list}APT|$pkg|$ver\n"
                    apt_count=$((apt_count + 1))
                fi
            done < <(apt-get -s upgrade 2>/dev/null | grep -E '^Inst ')
        fi
        
        echo "80" ; echo "# Checking Flatpak & Snap updates..."
        local flatpak_count=0
        local flatpak_list=""
        if [ "$CHECK_FLATPAK" = "true" ] && command -v flatpak >/dev/null 2>&1; then
            while read -r line; do
                pkg=$(echo "$line" | awk '{print $1}')
                branch=$(echo "$line" | awk '{print $2}')
                remote=$(echo "$line" | awk '{print $4}')
                if [ -n "$pkg" ] && [ "$pkg" != "ID" ]; then
                    flatpak_list="${flatpak_list}Flatpak|$pkg|$branch ($remote)\n"
                    flatpak_count=$((flatpak_count + 1))
                fi
            done < <(flatpak update --check 2>/dev/null || true)
        fi
        
        local snap_count=0
        local snap_list=""
        if [ "$CHECK_SNAP" = "true" ] && command -v snap >/dev/null 2>&1; then
            while read -r line; do
                pkg=$(echo "$line" | awk '{print $1}')
                ver=$(echo "$line" | awk '{print $2}')
                if [ -n "$pkg" ] && [ "$pkg" != "Name" ]; then
                    snap_list="${snap_list}Snap|$pkg|$ver\n"
                    snap_count=$((snap_count + 1))
                fi
            done < <(snap refresh --list 2>/dev/null || true)
        fi
        
        echo -ne "$apt_list$flatpak_list$snap_list" > "$UPDATES_LIST_FILE"
        echo "100" ; echo "# Check complete!"
        sleep 1
    ) | zenity --progress \
        --title="Bodhi Update Utility" \
        --text="Checking for software updates..." \
        --percentage=0 \
        --auto-close \
        --width=400 2>/dev/null
        
    local exit_code=$?
    
    # Signal daemon process to reload config / update status
    local pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill -SIGUSR1 "$pid"
    fi
    
    if [ $exit_code -eq 0 ]; then
        local total_count=0
        if [ -f "$UPDATES_LIST_FILE" ]; then
            total_count=$(grep -c '|' "$UPDATES_LIST_FILE" 2>/dev/null || echo 0)
        fi
        
        if [ "$total_count" -gt 0 ]; then
            local zen_response
            zen_response=$(zenity --question \
                --title="Bodhi Update Utility" \
                --text="<span font='11' weight='bold'>System Updates Available</span>\n\nFound <b>$total_count</b> software updates ready for installation.\n\nWould you like to install them now?" \
                --icon-name="software-update-available" \
                --ok-label="Install Now" \
                --cancel-label="Remind Me Later" \
                --extra-button="Show Details" \
                --width=450 2>/dev/null)
            local exit_code=$?
                
            if [ "$zen_response" = "Show Details" ]; then
                show_details_dialog
            elif [ $exit_code -eq 0 ]; then
                install_updates
            fi
        else
            zenity --info \
                --title="Bodhi Update Utility" \
                --text="<span font='11' weight='bold'>System Up to Date</span>\n\nNo software updates are currently available." \
                --icon-name="emblem-synchronized" \
                --width=350 2>/dev/null
        fi
    fi
}

# --- Command Line Argument Routing ---
case "$1" in
    --check-now)
        run_manual_check_gui
        exit 0
        ;;
    --show-details)
        show_details_dialog
        exit 0
        ;;
    --install-now)
        install_updates
        exit 0
        ;;
    --settings)
        show_settings_gui
        exit 0
        ;;
    --repair)
        repair_package_manager
        exit 0
        ;;
    --help|-h)
        echo "Usage: $0 [OPTION]"
        echo "Options:"
        echo "  (none)            Start the background update checker daemon"
        echo "  --check-now       Perform an interactive check with progress bar"
        echo "  --show-details    Display the Zenity list of available updates"
        echo "  --install-now     Launch the package upgrade terminal/GUI"
        echo "  --settings        Show the GUI Settings form"
        echo "  --repair          Launch package manager repairs in terminal"
        exit 0
        ;;
esac

# --- System Tray Applet Lifecycle ---
start_tray_applet() {
    if command -v python3 >/dev/null 2>&1; then
        if ! pgrep -f "bodhi-update-tray.py" >/dev/null 2>&1; then
            log_message "INFO" "Starting system tray applet..."
            python3 "$SCRIPT_DIR/bodhi-update-tray.py" &
        fi
    fi
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
    pkill -f "bodhi-update-tray.py" || true
    log_message "INFO" "Notifier service stopped."
}
trap cleanup EXIT INT TERM

log_message "INFO" "Bodhi Update Notifier service started. Check interval: $CHECK_INTERVAL"

# Start system tray applet
start_tray_applet

# Convert check interval to seconds
SLEEP_SECONDS=$(parse_interval "$CHECK_INTERVAL")
RETRY_SECONDS=300
LAST_NOTIFIED_COUNT=0

# Trap SIGUSR1 to reload configuration and run an instant check
trigger_manual_check() {
    log_message "INFO" "Manual check requested. Reloading configuration..."
    load_config
    SLEEP_SECONDS=$(parse_interval "$CHECK_INTERVAL")
}
trap trigger_manual_check USR1

while true; do
    log_message "DEBUG" "Starting update check cycle..."

    # Ensure tray is running
    start_tray_applet

    # 1. Check Internet Connection
    if ! check_internet; then
        log_message "WARNING" "No internet connection detected. Retrying in 5 minutes..."
        sleep "$RETRY_SECONDS" &
        wait $! 2>/dev/null || true
        continue
    fi

    # 2. Silently update APT package lists
    log_message "DEBUG" "Refreshing package indexes..."
    if sudo -n apt-get update >/dev/null 2>&1; then
        log_message "INFO" "Package index refreshed successfully via sudo."
    else
        log_message "INFO" "Silent 'apt-get update' skipped. Using existing cache."
    fi

    # 3. Check for upgradable packages
    APT_COUNT=0
    APT_LIST=""
    FLATPAK_COUNT=0
    FLATPAK_LIST=""
    SNAP_COUNT=0
    SNAP_LIST=""

    # Check APT
    if [ "$CHECK_APT" = "true" ]; then
        log_message "DEBUG" "Checking APT updates..."
        while read -r line; do
            pkg=$(echo "$line" | awk '{print $2}')
            ver=$(echo "$line" | awk '{print $4}' | sed 's/[(]//g')
            if [ -n "$pkg" ]; then
                APT_LIST="${APT_LIST}APT|$pkg|$ver\n"
                APT_COUNT=$((APT_COUNT + 1))
            fi
        done < <(apt-get -s upgrade 2>/dev/null | grep -E '^Inst ')
    fi

    # Check Flatpak
    if [ "$CHECK_FLATPAK" = "true" ] && command -v flatpak >/dev/null 2>&1; then
        log_message "DEBUG" "Checking Flatpak updates..."
        while read -r line; do
            pkg=$(echo "$line" | awk '{print $1}')
            branch=$(echo "$line" | awk '{print $2}')
            remote=$(echo "$line" | awk '{print $4}')
            if [ -n "$pkg" ] && [ "$pkg" != "ID" ]; then
                FLATPAK_LIST="${FLATPAK_LIST}Flatpak|$pkg|$branch ($remote)\n"
                FLATPAK_COUNT=$((FLATPAK_COUNT + 1))
            fi
        done < <(flatpak update --check 2>/dev/null || true)
    fi

    # Check Snap
    if [ "$CHECK_SNAP" = "true" ] && command -v snap >/dev/null 2>&1; then
        log_message "DEBUG" "Checking Snap updates..."
        while read -r line; do
            pkg=$(echo "$line" | awk '{print $1}')
            ver=$(echo "$line" | awk '{print $2}')
            if [ -n "$pkg" ] && [ "$pkg" != "Name" ]; then
                SNAP_LIST="${SNAP_LIST}Snap|$pkg|$ver\n"
                SNAP_COUNT=$((SNAP_COUNT + 1))
            fi
        done < <(snap refresh --list 2>/dev/null || true)
    fi

    TOTAL_COUNT=$((APT_COUNT + FLATPAK_COUNT + SNAP_COUNT))
    echo -ne "$APT_LIST$FLATPAK_LIST$SNAP_LIST" > "$UPDATES_LIST_FILE"

# --- Feature 7: Silent Auto-Updates Engine ---
perform_silent_auto_update() {
    log_message "INFO" "Executing silent auto-update sequence..."
    send_notification "Bodhi Update Utility" "Starting silent background software update..."
    
    # 1. Update APT
    if [ "$CHECK_APT" = "true" ]; then
        log_message "INFO" "Silent updating APT packages..."
        if sudo -n apt-get upgrade -y >/dev/null 2>&1 && sudo -n apt-get autoremove -y >/dev/null 2>&1; then
            log_message "INFO" "APT packages silently upgraded via passwordless sudo."
        elif command -v pkexec >/dev/null 2>&1; then
            pkexec env DEBIAN_FRONTEND=noninteractive apt-get upgrade -y >/dev/null 2>&1 || true
            pkexec env DEBIAN_FRONTEND=noninteractive apt-get autoremove -y >/dev/null 2>&1 || true
        fi
    fi
    
    # 2. Update Flatpak
    if [ "$CHECK_FLATPAK" = "true" ] && command -v flatpak >/dev/null 2>&1; then
        log_message "INFO" "Silent updating Flatpak packages..."
        flatpak update -y >/dev/null 2>&1 || true
    fi
    
    # 3. Update Snap
    if [ "$CHECK_SNAP" = "true" ] && command -v snap >/dev/null 2>&1; then
        log_message "INFO" "Silent updating Snap packages..."
        sudo -n snap refresh >/dev/null 2>&1 || pkexec snap refresh >/dev/null 2>&1 || true
    fi
    
    # 4. Verify post-update state
    local remain_count=$(apt-get -s upgrade 2>/dev/null | grep -E '^Inst ' | wc -l)
    if [ "$remain_count" -eq 0 ]; then
        log_message "INFO" "Silent auto-update finished. 0 updates remaining."
        echo -n "" > "$UPDATES_LIST_FILE"
        send_notification "System Updated" "Silent auto-update completed successfully. System is up to date."
    else
        log_message "WARNING" "Silent auto-update finished, $remain_count package(s) remain."
    fi
    
    # Signal daemon / tray applet
    local pid=$(cat "$LOCK_FILE" 2>/dev/null)
    if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
        kill -SIGUSR1 "$pid"
    fi
}

    if [ "$TOTAL_COUNT" -gt 0 ]; then
        log_message "INFO" "Updates found! Total: $TOTAL_COUNT (APT: $APT_COUNT, Flatpak: $FLATPAK_COUNT, Snap: $SNAP_COUNT)"
        
        if [ "$SILENT_AUTO_UPDATE" = "true" ]; then
            log_message "INFO" "Silent Auto-Update enabled. Performing automatic upgrade..."
            perform_silent_auto_update
        else
            # Ensure DISPLAY is set
            if [ -z "$DISPLAY" ]; then
                export DISPLAY=":0.0"
            fi
        
        # 4. Trigger Desktop Notification (if count changed)
        if [ "$TOTAL_COUNT" -ne "$LAST_NOTIFIED_COUNT" ]; then
            log_message "INFO" "Triggering desktop notification for $TOTAL_COUNT updates."
            
            local detail_msg="APT: $APT_COUNT"
            [ "$FLATPAK_COUNT" -gt 0 ] && detail_msg="$detail_msg, Flatpak: $FLATPAK_COUNT"
            [ "$SNAP_COUNT" -gt 0 ] && detail_msg="$detail_msg, Snap: $SNAP_COUNT"
            
            send_notification "System Updates Available" "There are $TOTAL_COUNT updates available ($detail_msg). Click the tray icon to install."
            LAST_NOTIFIED_COUNT=$TOTAL_COUNT
            
            # Check for Quiet Hours (DND) before showing full blocking Zenity popup dialog
            if is_quiet_hours; then
                log_message "INFO" "Quiet Hours active. Blocking Zenity prompt skipped."
            else
                # Generate warning warnings if metered warning is active
                local warning_text=""
                if [ "$METERED_WARNING" = "true" ]; then
                    local size_val=$(get_download_size_val_mb)
                    local size_str=$(get_download_size_mb)
                    
                    if is_connection_metered; then
                        warning_text="\n\n⚠️ <b>Metered Network Active!</b> Downloading updates over a metered connection may incur data charges."
                    elif [ "$size_val" -ge "$METERED_THRESHOLD_MB" ]; then
                        warning_text="\n\n⚠️ <b>Large Update Warning:</b> This update requires downloading <b>$size_str</b> of data."
                    fi
                fi

                local zen_response
                zen_response=$(zenity --question \
                    --title="Bodhi Update Utility" \
                    --text="<span font='11' weight='bold'>System Updates Available</span>\n\nThere are <b>$TOTAL_COUNT</b> software updates ready for your Bodhi Linux system.$warning_text\n\nWould you like to install them now?" \
                    --icon-name="software-update-available" \
                    --ok-label="Install Now" \
                    --cancel-label="Remind Me Later" \
                    --extra-button="Show Details" \
                    --width=450 2>/dev/null)
                local exit_code=$?
                
                if [ "$zen_response" = "Show Details" ]; then
                    show_details_dialog
                elif [ $exit_code -eq 0 ]; then
                    install_updates
                fi
            fi
        fi
    fi
    else
        log_message "DEBUG" "No updates available. System is up to date."
        LAST_NOTIFIED_COUNT=0
    fi

    # Sleep in background (allows signal interruption)
    log_message "DEBUG" "Sleeping for $CHECK_INTERVAL ($SLEEP_SECONDS seconds)..."
    sleep "$SLEEP_SECONDS" &
    wait $! 2>/dev/null || true
done
