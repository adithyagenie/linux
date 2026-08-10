#!/usr/bin/env bash
# notify — telegram announcement after the bump pipeline.
# Env: UPSTREAM_VERSION (falls back to NEW_RELEASE_TAG), MERGE_CONFLICTS, RAISE (true/false),
#      FORK_REPO, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_IDS (comma- or space-separated)
set -euo pipefail

log(){ printf '› %s\n' "$*"; }

[ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_IDS:-}" ] || { log "no telegram secrets — skipping"; exit 0; }

MERGE_CONFLICTS=${MERGE_CONFLICTS:-0}
RAISE=${RAISE:-true}

# Version for the message: prefer UPSTREAM_VERSION, else derive from the tag.
VERSION="${UPSTREAM_VERSION:-${NEW_RELEASE_TAG:-}}"
VERSION="${VERSION#cachyos-}"
VERSION="${VERSION%-1}"
[ -n "$VERSION" ] || VERSION="unknown"

if [ "$RAISE" != "true" ]; then
  status_desc="no-op"
  emoji="ℹ️"
elif [ "$MERGE_CONFLICTS" -gt 0 ] 2>/dev/null; then
  status_desc="conflict"
  emoji="❌"
else
  status_desc="clean"
  emoji="✅"
fi

URL="https://github.com/${FORK_REPO}/releases/tag/${NEW_RELEASE_TAG}"

# Split CHAT_IDS on comma OR whitespace.
# Use printf to build a single string and split on any of , ; \n or space
tok=""
for ch in "${TELEGRAM_CHAT_IDS//,/ }"; do
  tok+="$ch "
done
# trailing space-offTokenizer? split posperse:
IFS=' ' read -ra IDS_UNSET <<< "$tok"
# fall back to ", " if still single — re-split on ',' as well
if [ "${#IDS_UNSET[@]}" -eq 1 ] && [[ "${IDS_UNSET[0]}" == *","* ]]; then
  IFS=',' read -ra IDS_UNSET <<< "${IDS_UNSET[0]}"
fi

for CHAT_ID in "${IDS_UNSET[@]}"; do
  [ -z "$CHAT_ID" ] && continue
  CURL_ARGS=(
    -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage"
    -d "chat_id=$CHAT_ID"
    -d "disable_web_page_preview=true"
  )
  # '+' encodes as space each multiline; use data-urlencode for text so \n become %0A
  CURL_ARGS+=( --data-urlencode "text=[$emoji] CachyOS stable $status_desc. Version: ${VERSION}. Conflicts: ${MERGE_CONFLICTS}. ${URL}" )
  curl "${CURL_ARGS[@]}" >/dev/null || log "curl to chat $CHAT_ID failed"
  log "sent telegram update to $CHAT_ID"
done

exit 0
