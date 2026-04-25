#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# 01-parse-upgrade-plan.sh
#
# Parses an upgrade plan from an issue body (or attached file) and extracts
# Maven coordinates.
#
# Required environment variables:
#   ISSUE_BODY   - The raw issue body text (or leave empty to use PLAN_FILE)
#   GH_TOKEN     - GitHub token (needed only if ISSUE_BODY contains a file URL)
#
# Optional environment variables:
#   PLAN_FILE    - Path to a local plan text file (bypasses URL download)
#   GITHUB_OUTPUT - Path to the output file (defaults to a temp file)
#
# Outputs written to $GITHUB_OUTPUT:
#   found              - 'true' if coordinates were found, 'false' otherwise
#   coordinates_file   - Path to file containing the extracted coordinates
# ------------------------------------------------------------------------------
set -euo pipefail

: "${GITHUB_OUTPUT:=$(mktemp)}"
export GITHUB_OUTPUT

WORK_DIR=$(mktemp -d)
PLAN_TEXT="$WORK_DIR/plan.txt"

if [[ -n "${PLAN_FILE:-}" ]]; then
  echo "Using local plan file: $PLAN_FILE"
  cp "$PLAN_FILE" "$PLAN_TEXT"
else
  # Check if the issue body contains a file attachment link
  FILE_URL=$(echo "${ISSUE_BODY:-}" \
    | grep -oP 'https://github\.com/[^)"\s]+' \
    | head -1 || true)

  if [[ -n "$FILE_URL" ]]; then
    echo "Downloading attached file from: $FILE_URL"
    curl -fsSL \
      -H "Authorization: Bearer ${GH_TOKEN:?GH_TOKEN is required to download from GitHub}" \
      -H "Accept: application/octet-stream" \
      -o "$PLAN_TEXT" \
      "$FILE_URL"
  else
    echo "Using inline issue body as plan text"
    echo "${ISSUE_BODY:-}" > "$PLAN_TEXT"
  fi
fi

# Extract Maven coordinates (group:artifact) from dependency
# lines like "	- org.example:artifact-name"
COORDS_FILE="$WORK_DIR/coordinates.txt"
grep -oP \
  '^\s*-\s+\K[A-Za-z0-9][A-Za-z0-9._-]*:[A-Za-z0-9][A-Za-z0-9._-]*' \
  "$PLAN_TEXT" \
  | sort -u \
  > "$COORDS_FILE" || true

COUNT=$(wc -l < "$COORDS_FILE" | tr -d ' ')
if [[ "$COUNT" -eq 0 ]]; then
  echo "::error::No Maven coordinates found in the upgrade plan output"
  echo "found=false" >> "$GITHUB_OUTPUT"
  echo "coordinates_file=$COORDS_FILE" >> "$GITHUB_OUTPUT"
  exit 0
fi

echo "Found $COUNT unique coordinates:"
cat "$COORDS_FILE"
echo "found=true" >> "$GITHUB_OUTPUT"
echo "coordinates_file=$COORDS_FILE" >> "$GITHUB_OUTPUT"

echo ""
echo "Outputs written to: $GITHUB_OUTPUT"
cat "$GITHUB_OUTPUT"
