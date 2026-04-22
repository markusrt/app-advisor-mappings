#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# 04-trim-versions.sh
#
# Trims mapping files to keep only the latest version per major (or the last 5
# versions when there is only one major).
#
# No required environment variables. Reads and writes files in mappings/*.json
# relative to the current working directory.
#
# Optional environment variables:
#   JQ_BIN  - Path to the jq executable (defaults to 'jq' on PATH)
#
# Run from the root of the repository.
# ------------------------------------------------------------------------------
set -euo pipefail

: "${JQ_BIN:=jq}"

cat > /tmp/trim_versions.jq << 'JQEOF'
def parse_version:
  split(".") | {major: (.[0] | tonumber), minor: (.[1] | tonumber), patch: (if length > 2 and .[2] != "x" then .[2]|tonumber else 0 end), key: (join("."))};
def sort_versions:
  sort_by([.major, .minor, .patch]);
.rewrite as $rewrite |
($rewrite | keys | map(parse_version) | sort_versions) as $all_versions |
($all_versions | map(.major) | unique) as $major_versions |
(
  if ($major_versions | length) == 1 then
    $all_versions | .[-5:]
  else
    $all_versions | group_by(.major) | map(last)
  end
) as $keep_versions |
($keep_versions | length) as $count |
(reduce range($count) as $i (
  {};
  ($keep_versions[$i]) as $ver |
  (if $i < ($count - 1) then
    {version: $keep_versions[$i + 1].key, project: (if $rewrite[$ver.key].nextRewrite then $rewrite[$ver.key].nextRewrite.project else null end)}
  else
    $rewrite[$ver.key].nextRewrite
  end) as $next |
  . + {
    ($ver.key): ($rewrite[$ver.key] | .nextRewrite = $next)
  }
)) as $new_rewrite |
.rewrite = $new_rewrite
JQEOF

echo "Trimming versions in mapping files..."
for f in mappings/*/*.json; do
  BEFORE=$("$JQ_BIN" '.rewrite | keys | length' "$f")
  "$JQ_BIN" --indent 2 -f /tmp/trim_versions.jq "$f" > "${f}.tmp" && mv "${f}.tmp" "$f"
  AFTER=$("$JQ_BIN" '.rewrite | keys | length' "$f")
  if [[ "$BEFORE" != "$AFTER" ]]; then
    echo "  $f: $BEFORE → $AFTER versions"
  fi
done
echo "✅ Version trimming complete"
