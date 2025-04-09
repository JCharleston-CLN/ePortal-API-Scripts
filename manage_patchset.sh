#!/bin/bash

# Usage:
# ./manage_patchset.sh <patchset> <feed1,feed2,...> <action> [product]

API_KEY="your api key here"
API_HEADER="X-Api-Key: $API_KEY"
BASE_URL="your eportal base url here"
ENDPOINT="/admin/api/patchsets/manage"

PATCHSET="$1"
FEEDS="$2"
ACTION="$3"
PRODUCT="${4:-kernel}"  # default to kernel if not provided

if [[ -z "$PATCHSET" || -z "$FEEDS" || -z "$ACTION" ]]; then
  echo "Usage: $0 <patchset> <feed1,feed2,...> <action> [product]"
  exit 1
fi

# Convert comma-separated feeds into repeated feed query params
IFS=',' read -ra FEED_ARRAY <<< "$FEEDS"
FEED_QUERY=""
for FEED in "${FEED_ARRAY[@]}"; do
  FEED_QUERY+="&feed=$FEED"
done

# Perform the POST request
curl -X POST "${BASE_URL}${ENDPOINT}?patchset=${PATCHSET}${FEED_QUERY}&action=${ACTION}&product=${PRODUCT}" \
  -H "$API_HEADER" \
  -d ""  # sending an empty body
