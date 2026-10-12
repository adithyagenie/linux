#!/usr/bin/env bash
# Stage: check — decide whether a bump is even needed (idempotency).
# Uses ls-remote (no local clone needed).
# Inputs (env): UPSTREAM_VERSION, FORK_REPO
# Output (GITHUB_OUTPUT): raise:true|false, reason, previous_release, new_release
set -euo pipefail

log(){ printf '› %s\n' "$*"; }

UPSTREAM_VERSION="${UPSTREAM_VERSION:?upstream version missing}"
FORK_REPO="${FORK_REPO:?fork repo missing}"

NEW_RELEASE="cachyos-$UPSTREAM_VERSION-1"

if git ls-remote --exit-code "https://github.com/$FORK_REPO" "refs/tags/$NEW_RELEASE" >/dev/null 2>&1; then
  raise="false"; reason="tag $NEW_RELEASE already exists"
else
  raise="true"; reason="upstream ahead ($UPSTREAM_VERSION not yet released)"
fi

prev_release_tag=$(git ls-remote "https://github.com/$FORK_REPO" 'refs/tags/cachyos-6.18.*-1' \
  | awk '{print $2}' | sed 's|refs/tags/||' | sort -V | tail -n1 || true)
[ -n "$prev_release_tag" ] || { echo "can't determine previous release"; exit 1; }

{
  echo "raise=$raise"
  echo "reason=$reason"
  echo "previous_release_tag=$prev_release_tag"
  echo "new_release_tag=$NEW_RELEASE"
} >> "$GITHUB_OUTPUT"

log "check: $reason"