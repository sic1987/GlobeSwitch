#!/bin/bash
# GlobeSwitch — installs the latest GitHub release into Applications with one command:
#   curl -fsSL https://raw.githubusercontent.com/sic1987/GlobeSwitch/main/install.sh | bash
set -euo pipefail

REPO="sic1987/GlobeSwitch"
NAME="GlobeSwitch"
BUNDLE_ID="com.sicdesign.GlobeSwitch"

echo "GlobeSwitch — install"
URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -o '"browser_download_url": *"[^"]*\.zip"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')
[ -n "$URL" ] || { echo "Could not find a zip in the latest release at https://github.com/$REPO/releases" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "${TMP:?}"' EXIT
echo "Downloading ${URL##*/} …"
curl -fsSL "$URL" -o "$TMP/$NAME.zip"
ditto -x -k "$TMP/$NAME.zip" "$TMP/unzipped"
APP=$(find "$TMP/unzipped" -maxdepth 2 -name "$NAME.app" | head -1)
[ -d "$APP" ] || { echo "No $NAME.app in the archive" >&2; exit 1; }

DEST="/Applications"; [ -w "$DEST" ] || DEST="$HOME/Applications"; mkdir -p "$DEST"
osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
pkill -x "$NAME" >/dev/null 2>&1 || true
sleep 0.5
rm -rf "${DEST:?}/${NAME:?}.app"
ditto "$APP" "$DEST/$NAME.app"
# The app is signed with the author's own certificate, not an Apple Developer ID, so Gatekeeper would
# refuse a downloaded copy; drop the quarantine flag the archive received when it was downloaded.
xattr -dr com.apple.quarantine "$DEST/$NAME.app" 2>/dev/null || true
echo "Installed: $DEST/$NAME.app"
open "$DEST/$NAME.app"
echo "Done. Next: allow Accessibility for GlobeSwitch in the macOS dialog,"
echo "and answer \"Turn Off\" when asked about the system's 🌐 key action."
