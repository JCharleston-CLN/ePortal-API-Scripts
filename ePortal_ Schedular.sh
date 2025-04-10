#!/bin/bash

# manage_or_schedule.sh
# Universal patchset scheduler and API tool

CRON_FILE="/tmp/my_temp_cron_$$"
EDITOR="${EDITOR:-vi}"

# API Config
API_KEY="your api key here"
BASE_URL="your eportal base url here"
ENDPOINT="/admin/api/patchsets/manage"
API_HEADER="X-Api-Key: $API_KEY"

# OS detection
function detect_distro() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS_ID="macos"
        OS_NAME="macOS"
    elif [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_ID=$ID
        OS_NAME=$NAME
    else
        OS_ID="unknown"
        OS_NAME="Unknown Linux"
    fi
}

# Ensure cron is available and running
function ensure_cron_installed() {
    if [[ "$OS_ID" == "macos" ]]; then
        return
    fi

    if ! command -v crontab &>/dev/null; then
        echo "Cron not found. Installing..."

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
    fi
}

# Input validation helpers
function validate_patchset() {
    [[ "$1" =~ ^K[0-9]{8}_[0-9]{2}$ ]]
}

function validate_feeds() {
    [[ "$1" =~ ^[a-zA-Z0-9]+(,[a-zA-Z0-9]+)*$ ]]
}

function validate_action() {
    [[ "$1" == "enable" || "$1" == "disable" || "$1" == "enable-upto" || "$1" == "undeploy-downto" ]]
}

function validate_product() {
    [[ "$1" == "kernel" || "$1" == "user" || "$1" == "qemu" || "$1" == "db" ]]
}

function validate_date() {
    date -d "$1" "+%Y-%m-%d" >/dev/null 2>&1
}

function validate_time() {
    [[ "$1" =~ ^([01]?[0-9]|2[0-3]):[0-5][0-9]$ ]]
}

# Interactive task scheduler
function prompt_schedule() {
    echo "Scheduling a new task..."
    echo
    echo "Current server date and time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo

    # Patchset
    while true; do
        read -rp "Enter the patchset (e.g., K20250420_03): " PATCHSET
        validate_patchset "$PATCHSET" && break
        echo "Invalid patchset format. Expected: KYYYYMMDD_##"
    done

    # Feeds
    while true; do
        read -rp "Enter the target feed(s), comma-separated (e.g., test,production): " FEEDS
        validate_feeds "$FEEDS" && break
        echo "Invalid feed format. Use alphanumeric names separated by commas."
    done

    # Action
    while true; do
        read -rp "Enter the action (enable, disable, enable-upto, undeploy-downto): " ACTION
        validate_action "$ACTION" && break
        echo "Invalid action. Must be one of: enable, disable, enable-upto, undeploy-downto."
    done

    # Product
    while true; do
        read -rp "Enter the product (kernel, user, qemu, db) [default: kernel]: " PRODUCT
        PRODUCT="${PRODUCT:-kernel}"
        validate_product "$PRODUCT" && break
        echo "Invalid product. Choose from: kernel, user, qemu, db"
    done

    # Date
    while true; do
        read -rp "Enter the date to run the task (YYYY-MM-DD): " run_date
        validate_date "$run_date" && break
        echo "Invalid date. Format must be YYYY-MM-DD and must be valid."
    done

    # Time
    while true; do
        read -rp "Enter the time to run the task (24hr format, HH:MM): " run_time
        validate_time "$run_time" && break
        echo "Invalid time. Use 24-hour format HH:MM (e.g., 14:30)."
    done

    # Build cron time
    minute=$(echo "$run_time" | cut -d':' -f2)
    hour=$(echo "$run_time" | cut -d':' -f1)
    day=$(echo "$run_date" | cut -d'-' -f3)
    month=$(echo "$run_date" | cut -d'-' -f2)

    crontab -l 2>/dev/null > "$CRON_FILE"

    SCRIPT_PATH="$(realpath "$0")"
    full_command="sh $SCRIPT_PATH \"$PATCHSET\" \"$FEEDS\" \"$ACTION\" \"$PRODUCT\""

    echo "$minute $hour $day $month * $full_command" >> "$CRON_FILE"

    crontab "$CRON_FILE"
    rm -f "$CRON_FILE"

    echo
    echo "Task scheduled for $run_date at $run_time:"
    echo "   → $full_command"
}

# Cron cleanup
function prompt_cleanup() {
    echo "Cleaning up scheduled tasks..."

    crontab -l 2>/dev/null | nl -nln -w2 -s'. ' > "$CRON_FILE"

    if [[ ! -s "$CRON_FILE" ]]; then
        echo "No cron jobs found."
        rm -f "$CRON_FILE"
        return
    fi

    echo "Current scheduled tasks:"
    cat "$CRON_FILE"
    echo
    echo "Enter the number(s) of the task(s) to remove (e.g., 1 2 3), or leave blank to cancel:"
    read -r lines_to_delete

    if [[ -z "$lines_to_delete" ]]; then
        echo "Cleanup cancelled."
        rm -f "$CRON_FILE"
        return
    fi

    for line in $(echo "$lines_to_delete" | tr ' ' '\n' | sort -rn); do
        sed -i'' -e "${line}d" "$CRON_FILE" 2>/dev/null || sed -i "${line}d" "$CRON_FILE"
    done

    cut -d'.' -f2- "$CRON_FILE" | sed '/^$/d' | crontab -
    rm -f "$CRON_FILE"

    echo "Selected tasks removed from crontab."
}

# Patchset API runner
function run_patchset_api() {
    PATCHSET="$1"
    FEEDS="$2"
    ACTION="$3"
    PRODUCT="${4:-kernel}"

    if [[ -z "$PATCHSET" || -z "$FEEDS" || -z "$ACTION" ]]; then
        echo "Usage: $0 <patchset> <feed1,feed2,...> <action> [product]"
        exit 1
    fi

    IFS=',' read -ra FEED_ARRAY <<< "$FEEDS"
    FEED_QUERY=""
    for FEED in "${FEED_ARRAY[@]}"; do
        FEED_QUERY+="&feed=$FEED"
    done

    echo "Executing patchset API call..."
    echo "→ PATCHSET: $PATCHSET"
    echo "→ FEEDS: $FEEDS"
    echo "→ ACTION: $ACTION"
    echo "→ PRODUCT: $PRODUCT"

    curl -X POST "${BASE_URL}${ENDPOINT}?patchset=${PATCHSET}${FEED_QUERY}&action=${ACTION}&product=${PRODUCT}" \
        -H "$API_HEADER" \
        -d ""
}

# Entrypoint
detect_distro

# If script called with arguments, run as patchset API
if [[ "$#" -ge 3 ]]; then
    run_patchset_api "$@"
    exit 0
fi

# Otherwise run interactively
ensure_cron_installed

echo
echo "What would you like to do?"
echo "1) Create/Schedule a new patchset task"
echo "2) Clean existing scheduled tasks"
read -p " Enter 1 or 2: " choice

echo
case "$choice" in
    1) prompt_schedule ;;
    2) prompt_cleanup ;;
    *) echo "Invalid selection. Exiting." ;;
esac
