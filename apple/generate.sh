#!/bin/sh
# Makes Attest.xcodeproj. Your signing details are never committed; they are remembered in signing.local.env
# (gitignored, next to this script), so after the first run you can just type ./generate.sh.
#
#   First time:  DEVELOPMENT_TEAM=ABCDE12345 ATTEST_BUNDLE_ID=com.yourname.attest ./generate.sh
#   After that:  ./generate.sh
#
# Values given on the command line win, and are saved for next time. With nothing saved or given you get the
# placeholder bundle id (com.attest.app, which Apple has probably taken) and no team: pick the team in Xcode instead.
set -e
cd "$(dirname "$0")"
command -v xcodegen >/dev/null || { echo "Install XcodeGen first: brew install xcodegen" >&2; exit 1; }

CONF=signing.local.env
given_team="${DEVELOPMENT_TEAM:-}"
given_bid="${ATTEST_BUNDLE_ID:-}"
DEVELOPMENT_TEAM=""
ATTEST_BUNDLE_ID=""
# shellcheck disable=SC1090
[ -f "$CONF" ] && . "./$CONF"
[ -n "$given_team" ] && DEVELOPMENT_TEAM="$given_team"
[ -n "$given_bid" ] && ATTEST_BUNDLE_ID="$given_bid"

if [ -n "$given_team$given_bid" ]; then
  printf 'DEVELOPMENT_TEAM=%s\nATTEST_BUNDLE_ID=%s\n' "$DEVELOPMENT_TEAM" "$ATTEST_BUNDLE_ID" > "$CONF"
  echo "Saved your signing details to apple/$CONF (not committed)."
fi

export DEVELOPMENT_TEAM
export ATTEST_BUNDLE_ID="${ATTEST_BUNDLE_ID:-com.attest.app}"
xcodegen generate
echo "Bundle id: $ATTEST_BUNDLE_ID   Team: ${DEVELOPMENT_TEAM:-(choose in Xcode)}"
if [ -z "$DEVELOPMENT_TEAM" ] || [ "$ATTEST_BUNDLE_ID" = "com.attest.app" ]; then
  echo "Nothing saved for signing yet. Run once with your own values and they are remembered:" >&2
  echo "  DEVELOPMENT_TEAM=ABCDE12345 ATTEST_BUNDLE_ID=com.yourname.attest ./generate.sh" >&2
fi
