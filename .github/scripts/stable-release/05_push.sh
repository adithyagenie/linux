#!/usr/bin/env bash
# Stage: push — push the merge tip + the new release tag to fork.
# Env: UPSTREAM_VERSION, NEW_RELEASE_TAG, BASE_BRANCH (default 6.18/base), FORK_REPO
set -euo pipefail

log(){ printf '› %s\n' "$*"; }

UPSTREAM_VERSION="${UPSTREAM_VERSION:?}"
REL="${NEW_RELEASE_TAG:?}"
BASE_BRANCH="${BASE_BRANCH:-6.18/base}"

git push origin "$BASE_BRANCH"
git push origin "$REL"

# Verify the fork now matches what we just pushed.
remote=$(git ls-remote "https://github.com/${FORK_REPO}" "refs/tags/$REL^{}" 2>/dev/null | awk '{print $1}')
local_tip=$(git rev-parse "$REL^{}")
[ "$remote" = "$local_tip" ] || { echo "push mismatch: $remote vs $local_tip"; exit 1; }
echo "rel_sha=$local_tip" >> "$GITHUB_OUTPUT"
log "pushed + verified: $BASE_BRANCH + $REL @ $local_tip"
