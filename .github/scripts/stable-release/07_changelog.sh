#!/usr/bin/env bash
# Stage: changelog — produce CachyOS-style release notes via the GitHub compare API.
# Uses `gh api` (workflow GITHUB_TOKEN env / local gh auth), like stage 8.
# Requires UPSTREAM_COMMIT reachable on the fork (base pushed in stage 5).
# Env:  NEW_RELEASE_TAG, PREVIOUS_RELEASE_TAG, UPSTREAM_VERSION, UPSTREAM_COMMIT, FORK_REPO
# Output (GITHUB_OUTPUT): notes_file
set -euo pipefail

log(){ printf '› %s\n' "$*"; }

REL="${NEW_RELEASE_TAG:?}"
PREV="${PREVIOUS_RELEASE_TAG:?}"
UPSTREAM_VERSION="${UPSTREAM_VERSION:?}"
UPSTREAM_COMMIT="${UPSTREAM_COMMIT:?}"
FORK_REPO="${FORK_REPO:?}"
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
    echo; echo "#### 6.18/$b"
    # compare API: commits[] is newest-first (like `git log`); reverse to match
    # the old `git log --reverse fork..tip` (oldest-first).
    gh api "repos/$FORK_REPO/compare/$UPSTREAM_COMMIT...6.18/$b" \
      | jq -r '.commits[] | "- `\(.sha[0:12])` \(.commit.message | split("\n")[0])"' \
      | tac
  done
} > "$notes"

LINES=$(wc -l < "$notes")
COUNT=$(grep -c '^#### 6.18/' "$notes" || echo 0)
log "notes: $LINES lines, $COUNT branches → $notes"
echo "notes_file=$notes" >> "$GITHUB_OUTPUT"
