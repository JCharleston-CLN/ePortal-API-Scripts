#!/bin/bash

# ePortal_Schedular.sh
# Script written by Jamie Charleston, Director of Global Sales Engineering, TuxCare
#This script and its associated files are provided "as is", without warranty of any kind 
# — express or implied. By using this code, you acknowledge that:

# You are responsible for understanding what the script does before running it.
# The author(s) are not liable for any damage, data loss, downtime, misconfiguration, 
# or unintended behavior resulting from the use or misuse of this script.
# This script may require modification to suit your environment and use case.
# No guarantees are made regarding the correctness, performance, or security of the code.

# Use responsibly and test thoroughly before using in a production environment.
# Universal patchset scheduler and API tool with multi-endpoint and feed validation support

CRON_FILE="/tmp/my_temp_cron_$$"
EDITOR="${EDITOR:-vi}"

# --- API CONFIGURATION ---
declare -A API_KEYS
declare -A BASE_URLS

# ----------------------------------------------------------
#  Edit section 1  Environment Configuration for API Access
# ----------------------------------------------------------

# This section defines API keys and base URLs for different 
# ePortal servers if you want to manage multiple ePortals
# (e.g. production, staging, and development).
# These values are used to dynamically select the correct 
# credentials and endpoints based on the deployment context.
# If you only have 1 ePortal, fill in ePortal 1 information 
# and comment out the additional ePortals. Make sure to provide
# name for each eportal in the []. [prodcution]

# ePortal 1 environment configuration
API_KEYS[production]="eportal1-api-key-here"              # API key used for the production environment
BASE_URLS[production]="https://eportal1.example.com" # Base URL for the production API

# ePortal 2 environment configuration
API_KEYS[staging]="eportal2-api-key-here"              # API key used for the staging environment (testing prior to production)
BASE_URLS[staging]="https://eportal2.example.com"       # Base URL for the staging API

# ePortal 3 environment configuration
API_KEYS[dev]="eportal3-api-key-here"                      # API key used for development and local testing
BASE_URLS[dev]="https://eportal3.example.com"               # Base URL for the development API

ENDPOINT="/admin/api/patchsets/manage"

# ----------------------------------------------------------
# Edit section 2   FEED CONFIGURATION 
# ----------------------------------------------------------

# List of allowed feed names for the system to process.
# These represent the recognized environments or channels 
# that the system supports for deployments, updates, etc.

# IMPORTANT:
# Make sure feed names provided elsewhere (e.g., in ePortal or scripts)
# match **exactly** — including case — with the names listed below.
# Feed names are case-sensitive and must be consistent to avoid issues.
ALLOWED_FEEDS=("test" "production" "staging" "devops" "qa")


# --- OS Detection ---
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

# --- Ensure Cron Installed ---
function ensure_cron_installed() {
    if [[ "$OS_ID" == "macos" ]]; then return; fi

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

# --- Validators ---
function validate_patchset() {
    [[ "$1" =~ ^K[0-9]{8}_[0-9]{2}$ ]]
}

function validate_feeds() {
    IFS=',' read -ra INPUT_FEEDS <<< "$1"

    for FEED in "${INPUT_FEEDS[@]}"; do
        FEED=$(echo "$FEED" | xargs)
        FOUND=false
        for VALID in "${ALLOWED_FEEDS[@]}"; do
            if [[ "$FEED" == "$VALID" ]]; then
                FOUND=true
                break
            fi
        done
        if [[ "$FOUND" == false ]]; then
            echo " → Invalid feed: $FEED"
            return 1
        fi
    done
    return 0
}

function validate_action() {
    local valid_actions=("enable" "disable" "enable-upto" "undeploy-downto")
    for action in "${valid_actions[@]}"; do
        [[ "$1" == "$action" ]] && return 0
    done
    return 1
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

# --- Scheduler ---
function prompt_schedule() {
    echo "Scheduling a new task..."
    echo
    echo "Current server date and time: $(date '+%Y-%m-%d %H:%M:%S')"
    echo

    while true; do
        read -rp "Enter the patchset (e.g., K20250420_03): " PATCHSET
        validate_patchset "$PATCHSET" && break
        echo "Invalid patchset format. Expected: KYYYYMMDD_##"
    done

    echo
    echo "Available feed names: ${ALLOWED_FEEDS[*]}"
    while true; do
        read -rp "Enter the target feed(s), comma-separated (e.g., test,production): " FEEDS
        validate_feeds "$FEEDS" && break
        echo "Invalid feed(s). Please choose from the list above."
    done

    while true; do
        read -rp "Enter the action (enable, disable, enable-upto, undeploy-downto): " ACTION
        ACTION=$(echo "$ACTION" | tr '[:upper:]' '[:lower:]')
        validate_action "$ACTION" && break
        echo "Invalid action. Must be one of: enable, disable, enable-upto, undeploy-downto."
    done

    while true; do
        read -rp "Enter the product (kernel, user, qemu, db) [default: kernel]: " PRODUCT
        PRODUCT="${PRODUCT:-kernel}"
        validate_product "$PRODUCT" && break
        echo "Invalid product. Choose from: kernel, user, qemu, db"
    done

    echo
    echo "Available API endpoints:"
    for key in "${!API_KEYS[@]}"; do
        echo "  → $key"
    done

    while true; do
        read -rp "Choose the API endpoint to use: " ENDPOINT_KEY
        if [[ -n "${API_KEYS[$ENDPOINT_KEY]}" ]]; then
            break
        fi
        echo "Invalid endpoint key. Please try again."
    done

    while true; do
        read -rp "Enter the date to run the task (YYYY-MM-DD): " run_date
        validate_date "$run_date" && break
        echo "Invalid date. Format must be YYYY-MM-DD and must be valid."
    done

    while true; do
        read -rp "Enter the time to run the task (24hr format, HH:MM): " run_time
        validate_time "$run_time" && break
        echo "Invalid time. Use 24-hour format HH:MM (e.g., 14:30)."
    done

    minute=$(echo "$run_time" | cut -d':' -f2)
    hour=$(echo "$run_time" | cut -d':' -f1)
    day=$(echo "$run_date" | cut -d'-' -f3)
    month=$(echo "$run_date" | cut -d'-' -f2)

    crontab -l 2>/dev/null > "$CRON_FILE"

    SCRIPT_PATH="$(realpath "$0")"
    full_command="sh $SCRIPT_PATH \"$PATCHSET\" \"$FEEDS\" \"$ACTION\" \"$PRODUCT\" \"$ENDPOINT_KEY\""

    echo "$minute $hour $day $month * $full_command" >> "$CRON_FILE"

    crontab "$CRON_FILE"
    rm -f "$CRON_FILE"

    echo
    echo "Task scheduled for $run_date at $run_time:"
    echo "   → $full_command"
}

# --- Cron Cleanup ---
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

# --- API Runner ---
function run_patchset_api() {
    PATCHSET="$1"
    FEEDS="$2"
    ACTION="$3"
    PRODUCT="${4:-kernel}"
    ENDPOINT_KEY="$5"

    if [[ -z "$PATCHSET" || -z "$FEEDS" || -z "$ACTION" || -z "$ENDPOINT_KEY" ]]; then
        echo "Usage: $0 <patchset> <feed1,feed2,...> <action> [product] <endpoint_key>"
        exit 1
    fi

    BASE_URL="${BASE_URLS[$ENDPOINT_KEY]}"
    API_KEY="${API_KEYS[$ENDPOINT_KEY]}"
    API_HEADER="X-Api-Key: $API_KEY"

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
    echo "→ ENDPOINT: $ENDPOINT_KEY ($BASE_URL)"

    curl -X POST "${BASE_URL}${ENDPOINT}?patchset=${PATCHSET}${FEED_QUERY}&action=${ACTION}&product=${PRODUCT}" \
        -H "$API_HEADER" \
        -d ""
}

# --- Entrypoint ---
detect_distro

if [[ "$#" -ge 5 ]]; then
    run_patchset_api "$@"
    exit 0
fi

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
