#!/usr/bin/env bash
# Stage: latest — find the newest upstream 6.18.y stable tag + commit (from git mirror).
# Output (GITHUB_OUTPUT): upstream_tag, upstream_version, upstream_commit
set -euo pipefail

STABLE_GITHUB="${STABLE_GITHUB:-https://github.com/gregkh/linux.git}"
STABLE_KO="${STABLE_KERNELORG:-https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git}"

log(){ printf '› %s\n' "$*"; }

# From github mirror first (reliable on runners), fall back to kernel.org.
list() {
  git ls-remote --tags "$STABLE_GITHUB" 'v6.18.*^{}' 'v6.18.*' 2>/dev/null \
      || git ls-remote --tags "$STABLE_KO"      'v6.18.*^{}' 'v6.18.*' 2>/dev/null
}

pairs=$(list)
# Mirrors list both 'v6.18.45' and its peeled form 'v6.18.45^{}'.
# Normalize to one row per version "version<TAB>commit", prefer the peeled row
# (it carries the commit sha), strip the ^{} suffix, and skip -rc review tags.
best=$(printf '%s\n' "$pairs" \
  | awk '/\^\{\}$/ && $2 !~ /-rc/ { sub(/\^\{\}$/,"",$2); print $2 "\t" $1 }' \
  | sed 's|refs/tags/v||' \
  | sort -V \
  | tail -n1 )

if [ -z "$best" ]; then
  # fallback: no peeled form (lightweight tags) — use the loose tag ref
  best=$(printf '%s\n' "$pairs" \
    | awk '!/\^\{\}$/ && $2 !~ /-rc/ { print $2 "\t" $1 }' \
    | sed 's|refs/tags/v||' \
    | sort -V | tail -n1)
fi

[ -n "$best" ] || { echo "no upstream v6.18.x tag found" >&2; exit 1; }

tag_v=${best%%$'\t'*}
sha=${best##*$'\t'}

{
  echo "upstream_tag=v${tag_v}"
  echo "upstream_version=${tag_v}"
  echo "upstream_commit=${sha}"
} >> "$GITHUB_OUTPUT"

log "upstream latest: v${tag_v} @ ${sha:0:12}"
