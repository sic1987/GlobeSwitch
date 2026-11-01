#!/bin/zsh
# Builds GlobeSwitch.app (release, ad-hoc signed).
#   ./build.sh            -> build/GlobeSwitch.app
#   ./build.sh --install  -> also copies it to /Applications (or ~/Applications) and launches it
set -euo pipefail
cd "$(dirname "$0")"

NAME=GlobeSwitch
BUNDLE_ID=com.sicdesign.GlobeSwitch
OUT=build
APP="$OUT/$NAME.app"

if [[ ! -f Resources/AppIcon.icns ]]; then
  echo "• иконка"
  rm -rf "${OUT:?}/AppIcon.iconset"
  swift Tools/make_icon.swift "$OUT/AppIcon.iconset" >/dev/null
  iconutil -c icns "$OUT/AppIcon.iconset" -o Resources/AppIcon.icns
fi

echo "• swift build -c release"
swift build -c release 2>&1 | grep -Ev '^\[|^Fetching|^Creating' || true
BIN=".build/release/$NAME"
[[ -x "$BIN" ]] || { echo "сборка не удалась: нет $BIN" >&2; exit 1; }

rm -rf "${APP:?}"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/$NAME"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
printf 'APPL????' > "$APP/Contents/PkgInfo"
codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
echo "Собрано: $APP"

if [[ "${1:-}" == "--install" ]]; then
  DEST=/Applications
  [[ -w "$DEST" ]] || DEST="$HOME/Applications"
  mkdir -p "$DEST"
  OLD_HASH=$(codesign -dvvv "$DEST/$NAME.app" 2>&1 | awk -F= '/^CDHash=/{print $2}' || true)
  NEW_HASH=$(codesign -dvvv "$APP" 2>&1 | awk -F= '/^CDHash=/{print $2}')
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
  pkill -x "$NAME" >/dev/null 2>&1 || true
  sleep 0.5
  rm -rf "${DEST:?}/${NAME:?}.app"
  cp -R "$APP" "$DEST/"
  echo "Установлено: $DEST/$NAME.app"
  if [[ "$OLD_HASH" != "$NEW_HASH" ]]; then
    # An ad-hoc signature changes with the code, and the old Accessibility grant would sit there as a
    # checked box that no longer matches the app: drop it so the app asks afresh.
    tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
    echo "Подпись изменилась — разрешение «Универсальный доступ» нужно выдать заново (приложение попросит само)."
  fi
  open "$DEST/$NAME.app"
fi
