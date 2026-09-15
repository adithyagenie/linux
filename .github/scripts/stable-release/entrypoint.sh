#!/usr/bin/env bash
# Pipeline entry point for the cachyos stable-release workflow.
# Each stage <NN_stage.sh> is self-contained and accepts its env.
set -euo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
LOG(){ printf '\033[1;34m[cachy]\033[0m %s\n' "$*"; }

run(){ "$@" ; }
export BASE_BRANCH="${BASE_BRANCH:-6.18/base}"
export FORK_REPO="${FORK_REPO:-adithyagenie/linux}"
export STABLE_GITHUB="${STABLE_GITHUB:-https://github.com/gregkh/linux.git}"
export STABLE_KERNELORG="${STABLE_KERNELORG:-https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git}"

main(){
  run bash "$DIR/01_latest.sh"
  run bash "$DIR/02_check.sh"
  run bash "$DIR/03_merge.sh"
  run bash "$DIR/04_tag.sh"
  run bash "$DIR/05_push.sh"
  run bash "$DIR/06_asset.sh"
  run bash "$DIR/07_changelog.sh"
  run bash "$DIR/08_release.sh"
  [ "${NOTIFY_SKIP:-0}" = 1 ] || run bash "$DIR/09_notify.sh"
  LOG "all requested stages finished"
}
main "$@"
