#!/bin/bash
# GlobeSwitch — установка последнего релиза с GitHub в «Программы» одной командой:
#   curl -fsSL https://raw.githubusercontent.com/sic1987/GlobeSwitch/main/install.sh | bash
set -euo pipefail

REPO="sic1987/GlobeSwitch"
NAME="GlobeSwitch"
BUNDLE_ID="com.sicdesign.GlobeSwitch"

echo "GlobeSwitch — установка"
URL=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
  | grep -o '"browser_download_url": *"[^"]*\.zip"' | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')
[ -n "$URL" ] || { echo "Не нашёл zip в последнем релизе https://github.com/$REPO/releases" >&2; exit 1; }

TMP=$(mktemp -d)
trap 'rm -rf "${TMP:?}"' EXIT
echo "Скачиваю ${URL##*/} …"
curl -fsSL "$URL" -o "$TMP/$NAME.zip"
ditto -x -k "$TMP/$NAME.zip" "$TMP/unzipped"
APP=$(find "$TMP/unzipped" -maxdepth 2 -name "$NAME.app" | head -1)
[ -d "$APP" ] || { echo "В архиве нет $NAME.app" >&2; exit 1; }

DEST="/Applications"; [ -w "$DEST" ] || DEST="$HOME/Applications"; mkdir -p "$DEST"
osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
pkill -x "$NAME" >/dev/null 2>&1 || true
sleep 0.5
rm -rf "${DEST:?}/${NAME:?}.app"
ditto "$APP" "$DEST/$NAME.app"
# Приложение подписано собственным сертификатом автора, а не Apple Developer ID, поэтому Gatekeeper
# не открыл бы скачанную копию; снимаем флаг карантина, который архив получил при скачивании.
xattr -dr com.apple.quarantine "$DEST/$NAME.app" 2>/dev/null || true
echo "Установлено: $DEST/$NAME.app"
open "$DEST/$NAME.app"
echo "Готово. Дальше: в окне macOS разрешите «Универсальный доступ» для GlobeSwitch,"
echo "а на вопрос про системное действие клавиши 🌐 ответьте «Отключить»."
