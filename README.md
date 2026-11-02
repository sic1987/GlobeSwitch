# GlobeSwitch

Мгновенное переключение раскладки клавиатуры по клавише 🌐 (Fn) на Mac.

Замена встроенного действия «Нажатие клавиши 🌐 → Сменить источник ввода», которое срабатывает
с задержкой, иногда пропускает нажатия и показывает медленный системный индикатор.

- одно короткое нажатие 🌐 — следующая раскладка, само переключение занимает 3–10 мс;
- свой лёгкий индикатор `RU` / `EN` на полсекунды (можно выключить) вместо системного;
- `Fn+стрелки`, `Fn+F1…F12`, `Fn+Delete`, `Fn+E` (эмодзи) и другие комбинации работают как раньше;
- живёт в строке меню (значок 🌐), окон нет; автозапуск при входе — одним пунктом меню;
- macOS 13 Ventura и новее, Apple Silicon и Intel; раскладок может быть сколько угодно, порядок —
  как в системном меню ввода.

## Установка

### Одной командой

Откройте Терминал и выполните:

```bash
curl -fsSL https://raw.githubusercontent.com/sic1987/GlobeSwitch/main/install.sh | bash
```

Скрипт скачает последний релиз с GitHub, положит `GlobeSwitch.app` в «Программы», снимет флаг
карантина и запустит приложение. [Текст скрипта](install.sh) — 40 строк, можно прочитать перед запуском.

### Вручную

1. Скачайте `GlobeSwitch-x.y.z.zip` на странице [Releases](https://github.com/sic1987/GlobeSwitch/releases),
   распакуйте и перетащите `GlobeSwitch.app` в «Программы».
2. Запустите. macOS скажет, что не может проверить разработчика: откройте **Системные настройки →
   Конфиденциальность и безопасность**, внизу нажмите **«Открыть всё равно»** и подтвердите.
   Так происходит потому, что приложение подписано собственным сертификатом автора, а не
   платным Apple Developer ID, и не проходило нотаризацию Apple.

### После первого запуска

1. macOS попросит разрешение **«Универсальный доступ»** — нажмите «Открыть настройки» и включите
   GlobeSwitch. Без него приложение не видит клавишу 🌐 (значок в строке меню остаётся серым).
2. Приложение спросит, **отключить ли системное переключение по клавише 🌐** — нажмите
   «Отключить». GlobeSwitch и так перехватывает клавишу у системы, но так надёжнее.
3. По желанию в меню приложения включите **«Запускать при входе в систему»**.

Готово: нажимайте 🌐, раскладка меняется сразу.

### Из исходников

Нужны только Command Line Tools (`xcode-select --install`), Xcode не требуется:

```bash
git clone https://github.com/sic1987/GlobeSwitch.git
cd GlobeSwitch
./build.sh --install
```

`build.sh` собирает `build/GlobeSwitch.app` (SwiftPM, release, universal), `--install` копирует его
в «Программы» и запускает, `--zip` упаковывает архив для релиза. Чтобы разрешение «Универсальный
доступ» не слетало при каждой пересборке, один раз выполните `Tools/make_signing_identity.sh`
(подробнее в разделе «Подпись»).

## Меню приложения

- список включённых раскладок — галочка у текущей, клик выбирает раскладку вручную;
- время последнего переключения в миллисекундах;
- **Показывать индикатор раскладки** — `RU` / `EN` на 0,6 с после переключения;
- **Перехватывать 🌐 у системы** — не отдавать системе событие клавиши Globe, чтобы её собственное
  действие (смена источника ввода, эмодзи, диктовка) не срабатывало вторым. Сам модификатор Fn
  другие программы видят как обычно. Выключайте только если системное действие клавиши 🌐
  стоит на «Ничего не делать»;
- **Запускать при входе в систему**;
- **Системное действие клавиши 🌐…** — открывает Системные настройки → Клавиатура;
- **О GlobeSwitch**, **Выйти**.

## Как это работает

- Приложение держит `CGEventTap` на уровне HID и видит нажатие и отпускание Fn. **Чистое нажатие**
  (между нажатием и отпусканием не нажато ничего другого: клавиши, модификаторы, кнопки мыши,
  клавиши яркости и громкости) = переключение на следующую включённую раскладку через
  `TISSelectInputSource`. Порядок раскладок берётся из системного списка (`AppleEnabledInputSources`).
- Переключение запускается сразу после возврата из колбэка event tap: внутри колбэка WindowServer
  ждёт нашего ответа, и запрос к серверу ввода там не выполняется.
- Что реально шлёт клавиша (macOS 15.7, MacBook Air M3): всегда `flagsChanged` с кодом 63 (Fn как
  модификатор) при нажатии и отпускании; после **короткого** нажатия (< ~0,3 с) система добавляет
  пару `keyDown`/`keyUp` с кодом 179 — «клавишу Globe», которая и запускает системное действие 🌐.
  GlobeSwitch переключает по отпусканию Fn, а пару 179 «съедает» и никак иначе не учитывает: иначе
  короткое нажатие давало два переключения, то есть ни одного.
- Первое реальное переключение в процессе стоит 100–250 мс (сервер ввода настраивает связь), поэтому
  при старте приложение один раз переключает раскладку туда и обратно — и первое ваше нажатие уже
  быстрое.
- При первом запуске приложение предлагает выключить системное действие
  (`com.apple.HIToolbox AppleFnUsageType = 0`, «Ничего не делать»).

## Подпись и разрешение «Универсальный доступ»

macOS хранит разрешение для *требования подписи* приложения. Релизы подписаны постоянным
сертификатом автора, поэтому обновление GlobeSwitch разрешение не сбрасывает.

При сборке из исходников без своей подписи `build.sh` подписывает ad-hoc, и каждая новая сборка
для macOS — другое приложение: скрипт установки сбрасывает устаревшую запись (`tccutil reset
Accessibility`), и приложение снова просит разрешение. Чтобы этого избежать, один раз выполните:

```bash
Tools/make_signing_identity.sh
```

Скрипт создаёт самоподписанный сертификат «GlobeSwitch Signing» в отдельной связке ключей
`~/Library/Keychains/GlobeSwitch.keychain-db` (пароль связки — в `.signing/keychain-password`,
папка не попадает в git), добавляет её в список поиска связок (иначе `codesign` идентичность не
находит) и просит один раз ввести пароль Mac, чтобы доверить сертификату подпись кода. Дальше
`build.sh` подписывает им автоматически, и разрешение живёт между сборками.

Если разрешение выдано, а значок остаётся серым, приложение через ~10 с один раз перезапустит
себя — macOS иногда применяет новое разрешение только к свежему процессу.

## Диагностика

```bash
/Applications/GlobeSwitch.app/Contents/MacOS/GlobeSwitch --list   # раскладки, * — текущая
/Applications/GlobeSwitch.app/Contents/MacOS/GlobeSwitch --next   # переключить и показать время
/usr/bin/log show --predicate 'subsystem == "com.sicdesign.GlobeSwitch"' --last 5m --style compact
```

В лог попадают только события Fn / Globe / медиа-клавиш и результаты переключения, обычные
нажатия клавиш — нет.

## Ограничения

- В полях ввода пароля (Secure Input) macOS не отдаёт события клавиатуры сторонним программам —
  там переключение через GlobeSwitch может не сработать.
- Клавиатуры без клавиши Fn/🌐 приложение не затрагивает.

## Удаление

Выйдите из GlobeSwitch (меню → Выйти), удалите `GlobeSwitch.app` из «Программ» и, если хотите,
верните системное действие клавиши 🌐 в Системных настройках → Клавиатура. Запись в «Универсальном
доступе» можно убрать там же или командой `tccutil reset Accessibility com.sicdesign.GlobeSwitch`.

## Структура проекта

```
Package.swift                           SwiftPM, один executable target
Sources/GlobeSwitch/main.swift          точка входа; --list / --next уходят в CLI
Sources/GlobeSwitch/FnTap.swift         event tap: чистое нажатие Fn, комбинации, клавиша Globe (179)
Sources/GlobeSwitch/InputSources.swift  список раскладок (TIS), порядок как в системе, selectNext, прогрев
Sources/GlobeSwitch/AppDelegate.swift   строка меню, разрешение, предложение выключить системное действие
Sources/GlobeSwitch/HUD.swift           индикатор RU/EN
Sources/GlobeSwitch/NativeFnSetting.swift  чтение/запись AppleFnUsageType
Sources/GlobeSwitch/Settings.swift      UserDefaults
Sources/GlobeSwitch/CLI.swift           диагностика из терминала
Sources/GlobeSwitch/Log.swift           каналы системного лога
Tools/make_icon.swift                   генерирует иконку (SF Symbol «globe» на синем)
Tools/make_signing_identity.sh          постоянная локальная подпись (сертификат + связка ключей)
Resources/Info.plist                    LSUIElement = true (без иконки в Dock)
build.sh                                сборка, упаковка в .app, подпись, --install, --zip
install.sh                              установка последнего релиза одной командой
```

## Автор

**sicdesign** — [sicdesign87@gmail.com](mailto:sicdesign87@gmail.com)

Лицензия [MIT](LICENSE).

---

## English

**GlobeSwitch** switches the keyboard layout instantly on a single press of the 🌐 (Fn) key on
macOS 13+, replacing the slow built-in "Press 🌐 key to → Change Input Source" action. A clean tap
(nothing else pressed while Fn is held) selects the next enabled input source in 3–10 ms; Fn+key
combinations keep working. Menu-bar only.

Install with one command:

```bash
curl -fsSL https://raw.githubusercontent.com/sic1987/GlobeSwitch/main/install.sh | bash
```

or download the zip from [Releases](https://github.com/sic1987/GlobeSwitch/releases), move the app to
Applications and allow it in System Settings → Privacy & Security → "Open Anyway" (the app is signed
with the author's own certificate, not notarized). Then grant Accessibility when asked and accept
the offer to turn the system's own 🌐 action off.

Build from source with Command Line Tools only: `./build.sh --install`.

Author: **sicdesign** — sicdesign87@gmail.com · MIT License.
