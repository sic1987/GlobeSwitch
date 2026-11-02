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
SIGN_NAME="GlobeSwitch Signing"
SIGN_KC="$HOME/Library/Keychains/GlobeSwitch.keychain-db"
signed_permanent=0
if [[ -f .signing/keychain-password && -f "$SIGN_KC" ]] \
   && security find-identity -v -p codesigning "$SIGN_KC" 2>/dev/null | grep -q "$SIGN_NAME"; then
  # codesign finds identities only through the user's keychain search list (its --keychain flag does not
  # find this one), so make sure the keychain is listed, then unlock it with the stored password.
  if ! security list-keychains -d user | grep -q "GlobeSwitch.keychain-db"; then
    security list-keychains -d user -s $(security list-keychains -d user | tr -d ' "') "$SIGN_KC"
  fi
  security unlock-keychain -p "$(cat .signing/keychain-password)" "$SIGN_KC"
  if codesign --force --sign "$SIGN_NAME" --timestamp=none --identifier "$BUNDLE_ID" "$APP"; then
    signed_permanent=1
  else
    echo "Подпись «$SIGN_NAME» не удалась — подписываю ad-hoc." >&2
  fi
fi
if (( signed_permanent )); then
  echo "Собрано: $APP — подпись «$SIGN_NAME» (постоянная: разрешение сохраняется между сборками)"
else
  codesign --force --sign - --identifier "$BUNDLE_ID" "$APP"
  echo "Собрано: $APP — подпись ad-hoc (разрешение придётся выдавать заново; см. Tools/make_signing_identity.sh)"
fi

if [[ "${1:-}" == "--install" ]]; then
  DEST=/Applications
  [[ -w "$DEST" ]] || DEST="$HOME/Applications"
  mkdir -p "$DEST"
  # macOS keeps the Accessibility grant for the app's *designated requirement*: with the permanent
  # identity it is "identifier … and certificate leaf = …" (stable), with ad-hoc it is the build's cdhash.
  OLD_REQ=$(codesign -d -r- "$DEST/$NAME.app" 2>/dev/null | grep '^designated' || true)
  NEW_REQ=$(codesign -d -r- "$APP" 2>/dev/null | grep '^designated' || true)
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
  pkill -x "$NAME" >/dev/null 2>&1 || true
  sleep 0.5
  rm -rf "${DEST:?}/${NAME:?}.app"
  cp -R "$APP" "$DEST/"
  echo "Установлено: $DEST/$NAME.app"
  if [[ "$OLD_REQ" != "$NEW_REQ" ]]; then
    # The old Accessibility grant would sit there as a checked box that no longer matches the app:
    # drop it so the app asks afresh.
    tccutil reset Accessibility "$BUNDLE_ID" >/dev/null 2>&1 || true
    echo "Требование подписи изменилось — разрешение «Универсальный доступ» нужно выдать заново (приложение попросит само)."
  else
    echo "Подпись та же — разрешение «Универсальный доступ» сохраняется."
  fi
  open "$DEST/$NAME.app"
fi
