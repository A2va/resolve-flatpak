#!/bin/sh
# Install DaVinci Resolve flatpak from a local flatpak-builder .repo.
# Usage: ./install.sh [--user|--system] [--free|--studio] [--repo=.repo] [--keep-remote] [-y]
#  Default: --user --free. Removes the temporary 'resolve-repo' remote
#  afterwards (installed app stays).
set -e
MODE="--user"
REPO=".repo"
WANT=""
KEEP=""
ASSUME_YES=""
for a in "$@"; do
  case "$a" in
    --system) MODE="--system";;
    --user) MODE="--user";;
    --studio) WANT="com.blackmagic.ResolveStudio";;
    --free) WANT="com.blackmagic.Resolve";;
    --repo=*) REPO="${a#--repo=}";;
    --keep-remote|--keep-repo) KEEP=1;;
    -y|--yes|--assumeyes) ASSUME_YES="-y";;
    -h|--help) sed -n '2,6p' "$0"; exit 0;;
    *) echo "Unknown option: $a (see --help)" >&2; exit 1;;
  esac
done
[ -d "$REPO" ] && [ -f "$REPO/config" ] || { echo "error: repo '$REPO' not found (run ./build.sh first)" >&2; exit 1; }
REPO_ABS="$(cd "$REPO" && pwd)"
# ostree ships with flatpak, no extra deps for ref check.
# Default is Free, falling back to Studio if Free wasn't built. Only one app
# is ever installed.
REFS="$(ostree refs --repo="$REPO_ABS")"
if [ -z "$WANT" ] && ! echo "$REFS" | grep -q "^app/com.blackmagic.Resolve/"; then
  WANT="com.blackmagic.ResolveStudio"
fi
[ -n "$WANT" ] || WANT="com.blackmagic.Resolve"
echo "$REFS" | grep -q "^app/$WANT/" || {
  echo "error: $WANT not in '$REPO'" >&2
  case "$WANT" in
    com.blackmagic.Resolve) echo "$REFS" | grep -q "^app/com.blackmagic.ResolveStudio/" && echo "hint: repo holds Studio only, retry with --studio" >&2;;
    *) echo "$REFS" | grep -q "^app/com.blackmagic.Resolve/" && echo "hint: repo holds Free only, retry with --free" >&2;;
  esac
  exit 1
}
SUDO=""; [ "$MODE" = "--system" ] && [ "$(id -u)" -ne 0 ] && SUDO="sudo"
# Replace stale remote so remote-add never fails; --no-gpg-verify: local build is unsigned.
$SUDO flatpak $MODE remote-delete --force resolve-repo 2>/dev/null || true
$SUDO flatpak $MODE remote-add --no-gpg-verify resolve-repo "$REPO_ABS"

[ -n "$KEEP" ] || trap "$SUDO flatpak $MODE remote-delete --force resolve-repo 2>/dev/null || true" EXIT INT TERM
# shellcheck disable=SC2086
$SUDO flatpak $MODE install $ASSUME_YES resolve-repo "$WANT"
if [ -z "$KEEP" ]; then
  trap - EXIT INT TERM
  $SUDO flatpak $MODE remote-delete --force resolve-repo
  echo "Removed temporary remote 'resolve-repo' (app stays installed)."
else
  echo "Kept remote 'resolve-repo'."
fi
echo "Installed:$WANT ($MODE)"
