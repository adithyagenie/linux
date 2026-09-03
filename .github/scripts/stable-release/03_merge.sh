#!/usr/bin/env bash
# Stage: merge — fetch the upstream stable tag and merge it into 6.18/base.
# Env: UPSTREAM_VERSION (e.g. 6.18.45), UPSTREAM_COMMIT, BASE_BRANCH (default 6.18/base),
#      STABLE_GITHUB (default https://github.com/gregkh/linux.git).
# Full fetch+merge output goes to a log file — NOT the GHA run log (storage).
# Outputs (GITHUB_OUTPUT): merge_rc, conflicts, merged, log_file
set -uo pipefail   # NOTE: no -e, we handle failures ourselves

log(){ printf '› %s\n' "$*"; }

UPSTREAM_VERSION="${UPSTREAM_VERSION:?upstream version required}"
BASE_BRANCH="${BASE_BRANCH:-6.18/base}"
STABLE_GITHUB="${STABLE_GITHUB:-https://github.com/gregkh/linux.git}"

MERGE_LOG_FILE="/tmp/merge-$UPSTREAM_VERSION.log"

git checkout -q "$BASE_BRANCH" || { echo "cannot checkout $BASE_BRANCH"; exit 1; }
log "merging upstream v$UPSTREAM_VERSION into $BASE_BRANCH (log: $MERGE_LOG_FILE)"

# --- fetch: output to log file only ---
{
  printf '## fetch v%s from %s (%s)\n' "$UPSTREAM_VERSION" "$STABLE_GITHUB" "$(date -u '+%F %T UTC')"
} > "$MERGE_LOG_FILE"
git fetch --no-tags "$STABLE_GITHUB" "refs/tags/v$UPSTREAM_VERSION:refs/tags/v$UPSTREAM_VERSION" >> "$MERGE_LOG_FILE" 2>&1
fetch_rc=$?
printf 'fetch rc=%d\n\n' "$fetch_rc" >> "$MERGE_LOG_FILE"

if [ $fetch_rc -ne 0 ]; then
  log "fetch of v$UPSTREAM_VERSION failed (rc=$fetch_rc) — see $MERGE_LOG_FILE"
  {
    echo "merge_rc=$fetch_rc"
    echo "conflicts=0"
    echo "merged=false"
    echo "log_file=$MERGE_LOG_FILE"
  } >> "$GITHUB_OUTPUT"
  exit 1
fi

# --- merge: output to log file only ---
printf '## merge v%s into %s\n' "$UPSTREAM_VERSION" "$BASE_BRANCH" >> "$MERGE_LOG_FILE"
git -c commit.gpgsign=false merge --no-ff "v$UPSTREAM_VERSION" \
  -m "Merge tag 'v$UPSTREAM_VERSION' of $STABLE_GITHUB into $BASE_BRANCH" >> "$MERGE_LOG_FILE" 2>&1
merge_rc=$?
printf 'merge rc=%d\n' "$merge_rc" >> "$MERGE_LOG_FILE"

if [ $merge_rc -eq 0 ]; then
  {
    echo "merge_rc=0"
    echo "conflicts=0"
    echo "merged=true"
    echo "log_file=$MERGE_LOG_FILE"
  } >> "$GITHUB_OUTPUT"
  printf 'merge v%s: clean\n' "$UPSTREAM_VERSION" >> "$GITHUB_STEP_SUMMARY"
  log "merge clean ✔"
  exit 0
fi

if git rev-parse -q --verify MERGE_HEAD >/dev/null 2>&1; then
  conflicts=$(git diff --name-only --diff-filter=U | wc -l)
  {
    printf '\n## conflicted files (%d)\n' "$conflicts"
    git diff --name-only --diff-filter=U
    printf '\n## conflict diffs\n'
    git diff --diff-filter=U
  } >> "$MERGE_LOG_FILE" 2>&1

  {
    echo "merge_rc=$merge_rc"
    echo "conflicts=$conflicts"
    echo "merged=false"
    echo "log_file=$MERGE_LOG_FILE"
  } >> "$GITHUB_OUTPUT"
  printf 'merge v%s: %d conflicts (log attached to telegram)\n' "$UPSTREAM_VERSION" "$conflicts" >> "$GITHUB_STEP_SUMMARY"

  git merge --abort || true
  log "merge conflicts=$conflicts — aborted, log at $MERGE_LOG_FILE"
  exit 0    # do NOT fail the job — notify attaches the log
fi

printf 'merge v%s: failed rc=%d (log: %s)\n' "$UPSTREAM_VERSION" "$merge_rc" "$MERGE_LOG_FILE" >> "$GITHUB_STEP_SUMMARY"
log "merge failed non-conflict (rc=$merge_rc) — see $MERGE_LOG_FILE"
{
  echo "merge_rc=$merge_rc"
  echo "conflicts=0"
  echo "merged=false"
  echo "log_file=$MERGE_LOG_FILE"
} >> "$GITHUB_OUTPUT"
exit 1
