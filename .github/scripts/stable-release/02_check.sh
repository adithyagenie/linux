#!/usr/bin/env bash
# Stage: check — decide whether a bump is even needed (idempotency).
# Inputs (env): UPSTREAM_VERSION, UPSTREAM_COMMIT
# Output (GITHUB_OUTPUT): raise:true|false, reason, previous_release, new_release
set -euo pipefail

log(){ printf '› %s\n' "$*"; }

# $UPSTREAM_VERSION = 6.18.45 (from the latest step's outputs or provided)
UPSTREAM_VERSION="${UPSTREAM_VERSION:?upstream version missing}"
UPSTREAM_COMMIT="${UPSTREAM_COMMIT:?upstream commit missing}"

NEW_RELEASE="cachyos-$UPSTREAM_VERSION-1"
if git rev-parse --verify -q "refs/tags/$NEW_RELEASE" >/dev/null; then
  raise="false"; reason="tag $NEW_RELEASE already exists"
elif git merge-base --is-ancestor "$UPSTREAM_COMMIT" 6.18/base; then
  raise="false"; reason="upstream v$UPSTREAM_VERSION is already covered by 6.18/base"
else
  raise="true"; reason="upstream ahead ($UPSTREAM_VERSION not yet released)"
fi

prev_release_tag=$(git tag --list 'cachyos-6.18.*-1' | sort -V | tail -n1 || true)
[ -n "$prev_release_tag" ] || { echo "can't determine previous release"; exit 1; }

{
  echo "raise=$raise"
  echo "reason=$reason"
  echo "previous_release_tag=$prev_release_tag"
  echo "new_release_tag=$NEW_RELEASE"
} >> "$GITHUB_OUTPUT"

log "check: $reason"
