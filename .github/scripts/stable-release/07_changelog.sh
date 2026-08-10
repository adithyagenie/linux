#!/usr/bin/env bash
# Stage: changelog — produce CachyOS-style release notes from the topic-branch manifests.
# Env:  NEW_RELEASE_TAG, PREVIOUS_RELEASE_TAG, UPSTREAM_VERSION, UPSTREAM_COMMIT
# Output (GITHUB_OUTPUT): notes_file
set -euo pipefail

log(){ printf '› %s\n' "$*"; }

REL="${NEW_RELEASE_TAG:?}"
PREV="${PREVIOUS_RELEASE_TAG:?}"
UPSTREAM_VERSION="${UPSTREAM_VERSION:?}"
UPSTREAM_COMMIT="${UPSTREAM_COMMIT:?}"
BRANCHES=(amd-pstate asus bbr3 cachy crypto fixes hdmi sched-ext t2)

notes="/tmp/changelog-$REL.md"
{
  echo "## CachyOS Linux $REL (fork adithyagenie/linux)"
  echo
  echo "Based on Linux $UPSTREAM_VERSION"
  echo "Previous release: \`$PREV\`"
  echo
  echo "### Changes since \`$PREV\`"
  echo
  prev_short="${PREV#cachyos-}"; prev_short="${prev_short%-1}"
  echo "- Rebased to upstream: \`$prev_short\` → \`$UPSTREAM_VERSION\`"
  echo
  echo "### Applied branches"
  for b in "${BRANCHES[@]}"; do
    tip=$(git rev-parse "origin/6.18/$b")
    fork=$(git merge-base "$UPSTREAM_COMMIT" "$tip")
    echo; echo "#### 6.18/$b"
    git log --reverse --abbrev=12 --format='- `%h` %s' "$fork..$tip"
  done
} > "$notes"

LINES=$(wc -l < "$notes")
COUNT=$(grep -c '^#### 6.18/' "$notes" || echo 0)
log "notes: $LINES lines, $COUNT branches → $notes"
echo "notes_file=$notes" >> "$GITHUB_OUTPUT"
