#!/bin/bash

API_KEY="Your API key Here"
API_HEADER="X-Api-Key: $API_KEY"
BASE_URL="Your ePortal Base URL here"
ENDPOINT="/admin/api/patchsets/manage"

echo "🛠️ Manage Patchset Deployment via API"
echo

# Prompt for patchset
read -p "Enter the patchset name (e.g., 2024-04): " PATCHSET
if [[ -z "$PATCHSET" ]]; then
  echo "Patchset is required."
  exit 1
fi

# Prompt for feed(s)
echo " Enter one or more feeds separated by commas (e.g., rhel8,rhel9)."
read -p "Feed(s): " FEEDS
if [[ -z "$FEEDS" ]]; then
  echo " At least one feed is required."
  exit 1
fi

# Prompt for action
echo " Select an action to perform:"
echo "  enable            → Enable the specified patchset"
echo "  disable           → Disable the specified patchset"
echo "  enable-upto       → Enable all patchsets up to (older than) specified"
echo "  undeploy-downto   → Undeploy all patchsets down to (newer than) specified"
read -p "Action: " ACTION
if [[ -z "$ACTION" ]]; then
  echo " Action is required."
  exit 1
fi

# Prompt for product (optional)
echo " Enter product type (optional, default: kernel):"
echo "  Options: kernel, user, qemu, db"
read -p "Product [kernel]: " PRODUCT
PRODUCT="${PRODUCT:-kernel}"  # default to kernel

# Convert comma-separated feeds into repeated feed query params
IFS=',' read -ra FEED_ARRAY <<< "$FEEDS"
FEED_QUERY=""
for FEED in "${FEED_ARRAY[@]}"; do
  FEED_QUERY+="&feed=$FEED"
done

# Confirm and show full request
FULL_URL="${BASE_URL}${ENDPOINT}?patchset=${PATCHSET}${FEED_QUERY}&action=${ACTION}&product=${PRODUCT}"

echo
echo "🚀 Sending POST request to:"
echo "$FULL_URL"
echo

# Send the POST request
curl -X POST "$FULL_URL" \
  -H "$API_HEADER" \
  -d ""  # empty body
