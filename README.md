# GlobeSwitch

Instant keyboard layout switching on a single press of the 🌐 (Fn) key on a Mac.

It replaces the built-in "Press 🌐 key to → Change Input Source" action, which reacts with a delay,
sometimes drops presses and shows a slow system indicator.

- one short tap of 🌐 — the next layout; the switch itself takes 3–10 ms;
- a light `RU` / `EN` indicator for half a second (can be turned off) instead of the system one;
- `Fn+arrows`, `Fn+F1…F12`, `Fn+Delete`, `Fn+E` (emoji) and other combinations work as before;
- lives in the menu bar (🌐 icon), no windows; launch at login is one menu item;
- macOS 13 Ventura or newer, Apple Silicon and Intel; any number of layouts, in the order of the
  system's input menu.

## Installation

### One command

Open Terminal and run:

```bash
curl -fsSL https://raw.githubusercontent.com/sic1987/GlobeSwitch/main/install.sh | bash
```

The script downloads the latest release from GitHub, puts `GlobeSwitch.app` into Applications,
removes the quarantine flag and launches the app. [The script](install.sh) is 40 lines — read it
first if you like.

### Manually

1. Download `GlobeSwitch-x.y.z.zip` from [Releases](https://github.com/sic1987/GlobeSwitch/releases),
   unpack it and drag `GlobeSwitch.app` into Applications.
2. Launch it. macOS will say it cannot verify the developer: open **System Settings → Privacy &
   Security**, click **"Open Anyway"** at the bottom and confirm. This happens because the app is
   signed with the author's own certificate rather than a paid Apple Developer ID, and it has not
   been notarized by Apple.

### After the first launch

1. macOS asks for the **Accessibility** permission — click "Open System Settings" and enable
   GlobeSwitch. Without it the app cannot see the 🌐 key (the menu-bar icon stays grey).
2. The app asks whether to **turn off the system's own 🌐 switching** — click "Turn Off". GlobeSwitch
   intercepts the key anyway, but this is the safer setup.
3. Optionally enable **"Launch at login"** in the app's menu.

Done: press 🌐 and the layout changes at once.

### From source

Only the Command Line Tools are needed (`xcode-select --install`), no Xcode:

```bash
git clone https://github.com/sic1987/GlobeSwitch.git
cd GlobeSwitch
./build.sh --install
```

`build.sh` builds `build/GlobeSwitch.app` (SwiftPM, release, universal), `--install` copies it into
Applications and launches it, `--zip` packs an archive for a release. To keep the Accessibility
permission from being reset on every rebuild, run `Tools/make_signing_identity.sh` once.

## App menu

- the list of enabled layouts — a check mark on the current one, a click selects a layout by hand;
- the time of the last switch in milliseconds;
- **Show layout indicator** — `RU` / `EN` for 0.6 s after a switch;
- **Intercept 🌐 from the system** — keep the Globe key event from the system so its own action
  (input source, emoji, dictation) does not fire as well. Other apps still see the Fn modifier as
  usual. Turn it off only if the system's 🌐 action is set to "Do Nothing";
- **Launch at login**;
- **System 🌐 key action…** — opens System Settings → Keyboard;
- **About GlobeSwitch**, **Quit**.

## Limitations

- In password fields (Secure Input) macOS does not pass keyboard events to third-party apps, so
  switching through GlobeSwitch may not work there.
- Keyboards without an Fn/🌐 key are not affected.

## Uninstall

Quit GlobeSwitch (menu → Quit), delete `GlobeSwitch.app` from Applications and, if you wish, restore
the system's 🌐 key action in System Settings → Keyboard. The Accessibility entry can be removed
there as well, or with `tccutil reset Accessibility com.sicdesign.GlobeSwitch`.

## Author

**sicdesign** — [sicdesign87@gmail.com](mailto:sicdesign87@gmail.com)

[MIT License](LICENSE).
