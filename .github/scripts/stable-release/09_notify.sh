#!/usr/bin/env bash
# notify — telegram announcement, only when the bump actually ran.
#   merged=true, no conflicts  → release message (markdown link, no previews)
#   merged=false (conflicts)   → failure message + merge log attached
#   RAISE != true (no-op)      → silent, exit 0
# Env: UPSTREAM_VERSION, PREVIOUS_RELEASE_TAG, NEW_RELEASE_TAG, MERGED,
#      MERGE_CONFLICTS, RAISE, FORK_REPO, RELEASE_URL, MERGE_LOG (path),
#      TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_IDS (comma- or whitespace-separated)
set -euo pipefail

log(){ printf '› %s\n' "$*"; }

[ -n "${TELEGRAM_BOT_TOKEN:-}" ] && [ -n "${TELEGRAM_CHAT_IDS:-}" ] || { log "no telegram secrets — skipping"; exit 0; }

RAISE="${RAISE:-}"
MERGED="${MERGED:-}"
MERGE_CONFLICTS="${MERGE_CONFLICTS:-0}"

# No bump happened this run → stay silent.
if [ "$RAISE" != "true" ]; then
  log "no-op run — no telegram message"
  exit 0
fi

UPSTREAM_VERSION="${UPSTREAM_VERSION:?upstream version missing}"
NEW_RELEASE_TAG="${NEW_RELEASE_TAG:?new release tag missing}"
RELEASE_URL="${RELEASE_URL:-https://github.com/${FORK_REPO}/releases/tag/${NEW_RELEASE_TAG}}"

# old -> new version numbers
NEW_V="${NEW_RELEASE_TAG#cachyos-}"; NEW_V="${NEW_V%-1}"
OLD_V="${PREVIOUS_RELEASE_TAG:-}"
OLD_V="${OLD_V#cachyos-}"; OLD_V="${OLD_V%-1}"

if [ "$MERGED" = "true" ]; then
  kind="release"
  TEXT="cachyos kernel update
Version ${OLD_V:-unknown} -> ${NEW_V}
[Release tag](${RELEASE_URL})"
else
  kind="conflict"
  TEXT="cachyos kernel update failed
Version ${OLD_V:-unknown} -> ${NEW_V}
${MERGE_CONFLICTS} merge conflicts.
log file attached"
fi

# Split CHAT_IDS on comma and/or whitespace.
IFS=', \t' read -ra IDS <<< "${TELEGRAM_CHAT_IDS//,/ }"

for CHAT_ID in "${IDS[@]}"; do
  [ -z "$CHAT_ID" ] && continue
  if [ "$kind" = "release" ]; then
    curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=$CHAT_ID" \
      -d "parse_mode=Markdown" \
      --data-urlencode 'link_preview_options={"is_disabled":true}' \
      --data-urlencode "text=$TEXT" >/dev/null \
      || log "curl sendMessage to chat $CHAT_ID failed"
  else
    LOG_FILE="${MERGE_LOG:-}"
    if [ -z "$LOG_FILE" ] || [ ! -f "$LOG_FILE" ]; then
      LOG_FILE=$(mktemp)
      printf 'merge log unavailable (merge step did not produce a log file)\n' > "$LOG_FILE"
    fi
    curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
      -d "chat_id=$CHAT_ID" \
      --data-urlencode "text=$TEXT" >/dev/null \
      || log "curl sendMessage to chat $CHAT_ID failed"
    curl -sS -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendDocument" \
      -F "chat_id=$CHAT_ID" \
      -F "document=@${LOG_FILE};filename=merge-$NEW_RELEASE_TAG.log" >/dev/null \
      || log "curl sendDocument to chat $CHAT_ID failed"
  fi
  log "sent telegram $kind message to $CHAT_ID"
done

exit 0
