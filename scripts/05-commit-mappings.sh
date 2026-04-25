#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# 05-commit-mappings.sh
#
# Commits and pushes generated mapping files and the updated MAPPINGS.md.
#
# Required environment variables:
#   ISSUE_NUMBER  - The GitHub issue number (used in the commit message)
#
# Optional environment variables:
#   GIT_BRANCH    - Branch to push to (defaults to 'main')
# ------------------------------------------------------------------------------
set -euo pipefail

: "${ISSUE_NUMBER:?ISSUE_NUMBER is required}"
: "${GIT_BRANCH:=main}"

git config user.name "github-actions[bot]"
git config user.email "github-actions[bot]@users.noreply.github.com"

git add mappings/ MAPPINGS.md
if git diff --cached --quiet; then
  echo "No changes to commit"
else
  git commit -m "Add advisor mappings from issue #${ISSUE_NUMBER}"
  git push origin "$GIT_BRANCH"
fi
