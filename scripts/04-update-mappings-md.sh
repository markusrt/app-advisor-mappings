#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# 04-update-mappings-md.sh
#
# Regenerates MAPPINGS.md from the coordinates TSV file.
#
# No required environment variables. Reads mappings/.coordinates.tsv and writes
# MAPPINGS.md relative to the current working directory.
#
# Run from the root of the repository.
# ------------------------------------------------------------------------------
set -euo pipefail

COORDS_TSV="mappings/.coordinates.tsv"

{
  echo "# Advisor Mappings"
  echo ""
  echo "This file is automatically maintained by the build workflow."
  echo "It lists all advisor mapping files along with links to the corresponding Maven Central artifacts."
  echo ""
  echo "| Group ID | Artifact ID | Maven Central | Mapping File |"
  echo "|----------|-------------|---------------|--------------|"

  if [[ -s "$COORDS_TSV" ]]; then
    sort -u "$COORDS_TSV" | while IFS=$'\t' read -r coord folder_slug; do
      [[ -z "$coord" ]] && continue
      group_id="${coord%%:*}"
      artifact_id="${coord##*:}"
      maven_url="https://central.sonatype.com/artifact/${group_id}/${artifact_id}"
      echo "| \`${group_id}\` | \`${artifact_id}\` | [Maven Central](${maven_url}) | [${folder_slug}](mappings/${folder_slug}) |"
    done
  fi
} > MAPPINGS.md

echo "✅ MAPPINGS.md updated"
