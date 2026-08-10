#!/usr/bin/env bash
# Stage: merge — fetch the upstream stable tag and merge it into 6.18/base.
# Env: UPSTREAM_VERSION (e.g. 6.18.45), UPSTREAM_COMMIT, BASE_BRANCH (default 6.18/base),
#      STABLE_GITHUB (default https://github.com/gregkh/linux.git).
# On conflict: MERGE_HEAD persists; exits non-zero with the conflict count on stderr-safe output.
set -uo pipefail   # NOTE: no -e, we handle failures ourselves

log(){ printf '› %s\n' "$*"; }

UPSTREAM_VERSION="${UPSTREAM_VERSION:?upstream version required}"
BASE_BRANCH="${BASE_BRANCH:-6.18/base}"
STABLE_GITHUB="${STABLE_GITHUB:-https://github.com/gregkh/linux.git}"

git checkout -q "$BASE_BRANCH" || { echo "cannot checkout $BASE_BRANCH"; exit 1; }
log "merging upstream v$UPSTREAM_VERSION into $BASE_BRANCH"

# Fetch just the exact upstream tag (objects enough for the merge).
git fetch --no-tags "$STABLE_GITHUB" "refs/tags/v$UPSTREAM_VERSION:refs/tags/v$UPSTREAM_VERSION"

MERGE_LOG=$(git -c commit.gpgsign=false merge --no-ff "v$UPSTREAM_VERSION" \
  -m "Merge tag 'v$UPSTREAM_VERSION' of $STABLE_GITHUB into $BASE_BRANCH" 2>&1)
merge_rc=$?

printf '%s\n' "$MERGE_LOG" >> "$GITHUB_STEP_SUMMARY"

if [ $merge_rc -eq 0 ]; then
  echo "merge_rc=0" >> "$GITHUB_OUTPUT"
  echo "conflicts=0" >> "$GITHUB_OUTPUT"
  echo "merged=true" >> "$GITHUB_OUTPUT"
  log "merge clean ✔"
else
  if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
    conflicts=$(git diff --name-only --diff-filter=U | wc -l)
    echo "merge_rc=$merge_rc" >> "$GITHUB_OUTPUT"
    echo "conflicts=$conflicts" >> "$GITHUB_OUTPUT"
    echo "merged=false" >> "$GITHUB_OUTPUT"
    git merge --abort || true
    log "merge conflicts=$conflicts — merge aborted, leaving fork untouched"
    printf 'merge_conflicts: %s\n%s\n' "$conflicts" "$(printf '%s\n' "$MERGE_LOG")" >> "$GITHUB_STEP_SUMMARY"
    exit 0    # do NOT fail the whole pipeline on conflicts — the rest can still notify
  fi
  log "merge failed non-conflict (rc=$merge_rc) — probe manually"
  printf 'merge failure (rc=%s):\n%s\n' "$merge_rc" "$MERGE_LOG" >> "$GITHUB_STEP_SUMMARY"
  exit 1
fi
