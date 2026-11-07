#!/usr/bin/env bash
# Stage: asset — build release tarball via git archive + compute SHA256/SRI.
# Env: NEW_RELEASE_TAG, FORK_REPO
set -euo pipefail

log(){ printf '› %s\n' "$*"; }

REL="${NEW_RELEASE_TAG:?}"

git archive --format=tar.gz --prefix="${REL}/" -o "/tmp/$REL.tar.gz" "$REL"
HEX=$(sha256sum "/tmp/$REL.tar.gz" | cut -d' ' -f1)
# No nix on GH runners — SRI is just sha256-<base64(raw digest)>.
SRI="sha256-$(printf '%s' "$HEX" | xxd -r -p | base64)"
SIZE=$(du -h "/tmp/$REL.tar.gz" | cut -f1)

echo "tar=/tmp/$REL.tar.gz" >> "$GITHUB_OUTPUT"
echo "sha256=$HEX" >> "$GITHUB_OUTPUT"
echo "sri=$SRI" >> "$GITHUB_OUTPUT"
echo "size=$SIZE" >> "$GITHUB_OUTPUT"

for att in "$REL.tar.gz"; do
  log "$att — $HEX, $SRI ($SIZE)"
done
