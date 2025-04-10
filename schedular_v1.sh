#!/bin/bash

# schedule_tool.sh
# Universal cron scheduler + cleaner for RHEL and Debian-based Linux

CRON_FILE="/tmp/my_temp_cron_$$"
EDITOR="${EDITOR:-vi}"

# Detect distro
function detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
        OS_NAME=$NAME
    else
        OS_ID="unknown"
        OS_NAME="Unknown Linux"
    fi
}

# Ensure cron is installed and running
function ensure_cron_installed() {
    echo "🔍 Checking if cron is installed..."

    if ! command -v crontab &>/dev/null; then
        echo "Cron not found. Installing on $OS_NAME..."

        if [[ "$OS_ID" == "ubuntu" || "$OS_ID" == "debian" ]]; then
            sudo apt-get update
            sudo apt-get install -y cron
            sudo systemctl enable --now cron
        elif [[ "$OS_ID" == "centos" || "$OS_ID" == "rhel" || "$OS_ID" == "rocky" || "$OS_ID" == "almalinux" ]]; then
            sudo yum install -y cronie
            sudo systemctl enable --now crond
        else
            echo "Unsupported distro: $OS_NAME"
            exit 1
        fi
    else
        echo "Cron is already installed."
    fi
}

function prompt_schedule() {
    echo "🛠 Scheduling a new task..."
    echo
    echo "Current server date and time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo

    # Get date
    echo "Enter the date to run the task (Example: 2025-04-12):"
    read -r run_date

    # Get time
    echo "Enter the time to run the task (24hr format, Example: 14:30):"
    read -r run_time

    # Get command
    echo "Enter the full command to run:"
    echo "  Example: /usr/bin/python3 /home/user/rollup.py --feed Production --patchset K20250220_07"
    read -r command

    # Convert date/time to cron format
    minute=$(echo "$run_time" | cut -d':' -f2)
    hour=$(echo "$run_time" | cut -d':' -f1)
    day=$(echo "$run_date" | cut -d'-' -f3)
    month=$(echo "$run_date" | cut -d'-' -f2)

    # Build and install cron job
    crontab -l 2>/dev/null > "$CRON_FILE"
    echo "$minute $hour $day $month * $command" >> "$CRON_FILE"

    crontab "$CRON_FILE"
    rm -f "$CRON_FILE"

    echo
    echo "Task scheduled for $run_date at $run_time"
    echo "   → $command"
}

function prompt_cleanup() {
    echo "Cleaning up scheduled tasks..."

    crontab -l 2>/dev/null | nl -w2 -s'. ' > "$CRON_FILE"

    if [[ ! -s "$CRON_FILE" ]]; then
        echo "No cron jobs found."
        rm -f "$CRON_FILE"
        return
    fi

    echo "Current scheduled tasks:"
    cat "$CRON_FILE"

    echo
    echo "Enter the number(s) of the task(s) to remove (e.g., 1 3 4), or leave blank to cancel:"
    read -r lines_to_delete

    if [[ -z "$lines_to_delete" ]]; then
        echo "Cleanup cancelled."
        rm -f "$CRON_FILE"
        return
    fi

    # Remove selected lines and update crontab
    for line in $lines_to_delete; do
        sed -i "${line}d" "$CRON_FILE"
    done

    cut -d'.' -f2- "$CRON_FILE" | sed '/^$/d' | crontab -
    rm -f "$CRON_FILE"

    echo "Selected tasks removed from crontab."
}

# Main runner
detect_distro
ensure_cron_installed

echo
echo "What would you like to do?"
echo "1) Create/Schedule a new task"
echo "2) Clean existing scheduled tasks"
read -p " Enter 1 or 2: " choice

echo
case "$choice" in
    1)
        prompt_schedule
        ;;
    2)
        prompt_cleanup
        ;;
    *)
        echo "Invalid selection. Exiting."
        exit 1
        ;;
esac
