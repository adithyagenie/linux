#!/usr/bin/env bash
# Stage: release — create GitHub Release on the fork + upload asset.
# Env:  NEW_RELEASE_TAG, UPSTREAM_VERSION, NOTES_FILE, TARBALL, ASSET_SHA256, FORK_REPO
# Behaviour: if the release already exists, update notes + clobber artifact.
set -euo pipefail

log(){ printf '› %s\n' "$*"; }

FORK_REPO="${FORK_REPO:?}"
REL="${NEW_RELEASE_TAG:?}"
VERSION="${UPSTREAM_VERSION:?}"
NOTES="${NOTES_FILE:?notes file missing}"
TARBALL="${TARBALL:?asset tarball missing}"
GH="${GH_BIN:-gh}"

# prefer the gh binary wherever it actually exists
if ! command -v "$GH" >/dev/null 2>&1; then
  for alt in /run/current-system/sw/bin/gh "$HOME"/.nix-profile/bin/gh; do
    [ -x "$alt" ] && GH="$alt" && break
  done
fi

log "creating / updating release $REL on $FORK_REPO (with $(command -v "$GH" || echo "$GH"))"

if "$GH" release view "$REL" --repo "$FORK_REPO" >/dev/null 2>&1; then
  "$GH" release edit "$REL" --repo "$FORK_REPO" --notes-file "$NOTES"
  "$GH" release upload "$REL" --repo "$FORK_REPO" --clobber "${TARBALL}"
  log "updated release $REL"
else
  "$GH" release create "$REL" --repo "$FORK_REPO" \
    --title "CachyOS Linux $REL" \
    --notes-file "$NOTES" \
    "${TARBALL}"
  log "created release $REL"
fi

# verify remote asset checksum against our local tarball
remote_digest=$("$GH" release view "$REL" --repo "$FORK_REPO" --json assets \
  --jq ".assets[]|select(.name==\"$REL.tar.gz\")|.digest" 2>/dev/null || true)
[ -n "$remote_digest" ] || { echo "release exists but no asset named $REL.tar.gz"; exit 1; }
if [ "$remote_digest" = "sha256:$ASSET_SHA256" ]; then
  log "remote asset digest verified: $remote_digest"
else
  log "WARNING remote digest differs: $remote_digest vs sha256:$ASSET_SHA256"
fi
echo "release_url=https://github.com/$FORK_REPO/releases/tag/$REL" >> "$GITHUB_OUTPUT"
