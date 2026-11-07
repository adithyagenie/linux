#!/usr/bin/env bash
# Stage: tag — create cachyos-6.18.x-1 on 6.18/base (or
# ` git merge --ff-only` if we want to keep tag <-> branch identity);
#  this one uses annotated GPG-off tags, matching fork's hand-built releases.
# Env: UPSTREAM_VERSION, PREVIOUS_RELEASE_TAG, NEW_RELEASE_TAG, BASE_BRANCH
set -euo pipefail

log(){ printf '› %s\n' "$*"; }

UPSTREAM_VERSION="${UPSTREAM_VERSION:?}"
PREV="${PREVIOUS_RELEASE_TAG:?}"
REL="${NEW_RELEASE_TAG:?}"
BASE_BRANCH="${BASE_BRANCH:-6.18/base}"

# Build a fork-friendly message mirroring CachyOS light style but record our
# plan-accoutrements: previous tag + upstream merge-from.
prev_short="${PREV#cachyos-}"; prev_short="${prev_short%-1}"
if git rev-parse --verify -q "refs/tags/$REL" >/dev/null; then
  log "tag $REL exists — nothing to tag"
  echo "shasame=$(git rev-parse --short "$REL^{}")" >> "$GITHUB_OUTPUT"
  exit 0
fi

git -c tag.gpgsign=false tag -a "$REL" \
  -m "Based on Linux $UPSTREAM_VERSION
Previous release: $PREV
Rebased to upstream: $prev_short -> $UPSTREAM_VERSION"

log "tagged $REL"
