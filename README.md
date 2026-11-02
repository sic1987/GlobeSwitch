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
доступ» не слетало при каждой пересборке, один раз выполните `Tools/make_signing_identity.sh`.

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

## Ограничения

- В полях ввода пароля (Secure Input) macOS не отдаёт события клавиатуры сторонним программам —
  там переключение через GlobeSwitch может не сработать.
- Клавиатуры без клавиши Fn/🌐 приложение не затрагивает.

## Удаление

Выйдите из GlobeSwitch (меню → Выйти), удалите `GlobeSwitch.app` из «Программ» и, если хотите,
верните системное действие клавиши 🌐 в Системных настройках → Клавиатура. Запись в «Универсальном
доступе» можно убрать там же или командой `tccutil reset Accessibility com.sicdesign.GlobeSwitch`.

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
