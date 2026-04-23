#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# 03-generate-mappings.sh
#
# Generates advisor mapping files for each Maven coordinate.
#
# Required environment variables:
#   COORDS_FILE    - Path to a file containing one Maven coordinate per line
#                    (output of 01-parse-upgrade-plan.sh)
#
# Optional environment variables:
#   ADVISOR_BIN    - Path to the advisor executable (defaults to 'advisor' on PATH)
#   JQ_BIN         - Path to the jq executable (defaults to 'jq' on PATH)
#   GITHUB_OUTPUT  - Path to the output file (defaults to a temp file)
#
# Outputs written to $GITHUB_OUTPUT:
#   raw_output_dir  - Directory containing per-coordinate raw advisor output and
#                     generated JSON files (./mappings/)
#   successes       - Multiline list of successfully processed coordinates
#   failures        - Multiline list of failed coordinates
#   has_failures    - 'true' if any coordinate failed
#   mapping_count   - Number of JSON mapping files found at the root of mappings/
# ------------------------------------------------------------------------------
set -euo pipefail

: "${COORDS_FILE:?COORDS_FILE is required}"
: "${GITHUB_OUTPUT:=$(mktemp)}"
: "${ADVISOR_BIN:=advisor}"
: "${JQ_BIN:=jq}"
export GITHUB_OUTPUT

mkdir -p mappings

SUCCESSES_FILE=$(mktemp)
FAILURES_FILE=$(mktemp)

# raw_output_dir points to ./mappings/ so the artifact upload captures everything
echo "raw_output_dir=mappings" >> "$GITHUB_OUTPUT"

while IFS= read -r coord; do
  [[ -z "$coord" ]] && continue

  echo "============================================"
  echo "Generating mapping for $coord"
  echo "============================================"

  COORD_SLUG="${coord//:/_}"
  COORD_OUTPUT_DIR="mappings/${COORD_SLUG}"
  mkdir -p "$COORD_OUTPUT_DIR"

  # Clear any previously generated advisor JSON files so we can tell exactly
  # which files belong to this coordinate
  rm -f .advisor/mappings/*.json 2>/dev/null || true

  RAW_OUTPUT_FILE="$COORD_OUTPUT_DIR/${COORD_SLUG}.log"
  set +o pipefail
  "$ADVISOR_BIN" mapping create -c="$coord" < /dev/null 2>&1 | tee "$RAW_OUTPUT_FILE"
  advisor_exit=${PIPESTATUS[0]}
  set -o pipefail
  if [[ $advisor_exit -eq 0 ]]; then
    echo "✅ Successfully generated mapping for $coord"
    echo "- ${coord}" >> "$SUCCESSES_FILE"

    # Process each JSON written by advisor into .advisor/mappings/
    # Use dotglob so files like ".json" (no base name) are included
    shopt -s dotglob
    for advisor_json in .advisor/mappings/*.json; do
      [[ -f "$advisor_json" ]] || continue

      # Read slug from JSON and generate a unique suffix
      slug=$("$JQ_BIN" -r '.slug' "$advisor_json")
      # Fall back to the artifact ID portion of the coordinate if slug is empty
      if [[ -z "$slug" ]]; then
        slug="${coord##*:}"
      fi
      suffix=$(openssl rand -hex 3)
      new_name="${slug}-${suffix}.json"

      # Write renamed JSON (with updated slug field) into the per-coord subfolder
      "$JQ_BIN" --indent 2 --arg new_slug "${slug}-${suffix}" \
        '.slug = $new_slug' "$advisor_json" > "$COORD_OUTPUT_DIR/${new_name}"
    done

    shopt -u dotglob

    # Record coordinate → folder in .coordinates.tsv (skip if coord already present)
    if ! grep -qP "^${coord}\t" mappings/.coordinates.tsv 2>/dev/null; then
      printf '%s\t%s\n' "${coord}" "${COORD_SLUG}" >> mappings/.coordinates.tsv
    fi
  else
    echo "⚠️ Failed to generate mapping for $coord"
    echo "- ${coord}" >> "$FAILURES_FILE"
    # Still record the coord in the TSV so it appears in MAPPINGS.md
    if ! grep -qP "^${coord}\t" mappings/.coordinates.tsv 2>/dev/null; then
      printf '%s\t%s\n' "${coord}" "${COORD_SLUG}" >> mappings/.coordinates.tsv
    fi
  fi

done < "$COORDS_FILE"

{
  echo "successes<<EOF"
  cat "$SUCCESSES_FILE"
  echo "EOF"
} >> "$GITHUB_OUTPUT"

{
  echo "failures<<EOF"
  cat "$FAILURES_FILE"
  echo "EOF"
} >> "$GITHUB_OUTPUT"

HAS_FAILURES="false"
if [[ -s "$FAILURES_FILE" ]]; then
  HAS_FAILURES="true"
fi
echo "has_failures=$HAS_FAILURES" >> "$GITHUB_OUTPUT"

rm -f "$SUCCESSES_FILE" "$FAILURES_FILE"

# Count JSON files in per-coord subdirs of mappings/ (not at root)
MAPPING_COUNT=$(find mappings -mindepth 2 -maxdepth 2 -name '*.json' | wc -l)
echo "mapping_count=$MAPPING_COUNT" >> "$GITHUB_OUTPUT"

echo ""
echo "Outputs written to: $GITHUB_OUTPUT"
cat "$GITHUB_OUTPUT"
