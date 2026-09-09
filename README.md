<p align="center">
  <img src="assets/readme-banner.png" alt="BannerHither — notifications on the screen you're looking at" width="720">
</p>

# BannerHither

English | [한국어](docs/README.ko.md) | [日本語](docs/README.ja.md) | [简体中文](docs/README.zh-Hans.md) | [Deutsch](docs/README.de.md) | [Français](docs/README.fr.md) | [Español](docs/README.es.md)

[![CI](https://github.com/KJeon10/BannerHither/actions/workflows/ci.yml/badge.svg)](https://github.com/KJeon10/BannerHither/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

BannerHither is a small menu bar app for macOS that decides **which display notification
banners appear on**. macOS always shows banners on the primary display; with several monitors
that is often not the one you are looking at. BannerHither moves each banner, the moment it
appears, to the screen under your mouse pointer, the screen of the window you are working in,
or one display you pick.

https://github.com/user-attachments/assets/ddf9e632-9b7a-4af7-b8a3-e71b7254d386

## Install

### Download

1. Get `BannerHither-<version>.dmg` from the [Releases](https://github.com/KJeon10/BannerHither/releases) page.
2. Open the image and drag `BannerHither.app` onto the Applications shortcut.
3. Launch it from Applications. The app and the image are signed with a Developer ID and notarized, so macOS only asks the usual first-launch confirmation.

### Homebrew

```sh
brew install --cask KJeon10/tap/bannerhither
```

### Build it yourself

Prefer to build it yourself? See [Building from source](#building-from-source).

### First launch

BannerHither asks for the **Accessibility** permission (System Settings › Privacy & Security ›
Accessibility). That permission is what lets it move NotificationCenter's window. Once granted,
the engine starts automatically; the menu bar icon shows a bell with a badge while it is running.

Use *Send Test Notification* from the menu: a notification arrives three seconds later, which
is enough time to move the mouse to another display and watch where the banner lands.

Shortly after that, BannerHither asks one question, once: whether it may check for updates
automatically. See [Updates](#updates).

## Features

- **Screen under the mouse pointer** — banners follow you to whichever display you are using.
- **Screen of the active window** — banners appear next to the window that has focus, with the
  mouse screen as fallback.
- **Fixed display** — banners always go to one specific monitor. If that monitor is unplugged,
  macOS behaviour is left untouched until it returns.
- **System default** — do nothing, keep the app parked in the menu bar.
- Menu bar only, no Dock icon; Start/Stop toggle; Launch at Login; *Check for Updates…* and an About
  panel; a test notification with a 3-second delay so you can move the mouse; a *Copy Diagnostics*
  item for bug reports.
- Universal binary (Apple silicon and Intel); interface in English, Korean, Japanese, Simplified Chinese, German, French and Spanish.
- Needs exactly one permission: Accessibility. No data collection; the only network request is the
  optional update check (see [Privacy](#privacy)).

## Updates

BannerHither does not install updates itself. *Check for Updates…* in the menu compares your version with the
[latest release](https://github.com/KJeon10/BannerHither/releases/latest) and offers the download. With your
consent it also checks once a day in the background; a new version then appears as a menu item and as a dot on
the menu bar icon, without any dialog. *Skip This Version* hides a release until the next one is published.
If you installed through Homebrew, `brew upgrade --cask bannerhither` does the same job.

## How it works

`NotificationCenter.app` draws every banner inside one transparent, display-sized window and
places that window on the primary display whenever a banner is presented. BannerHither watches
NotificationCenter through the public Accessibility API: when the banner window appears at its
default position, the app sets the window's `AXPosition` so that its top-right corner coincides
with the top-right corner of the chosen display, which puts the banner exactly where macOS would
draw it natively on that display. Because the whole window moves, clicks, swipes and the close
button keep working.

The app only acts at *transitions* (a banner just appeared, or NotificationCenter just
repositioned it), so a banner never chases the mouse after it is on screen, and the Notification
Center panel, which NotificationCenter places on whichever display's clock you clicked, is never
touched.

This relies on undocumented behaviour of NotificationCenter that Apple may change in any macOS
update. If the window can no longer be found or moved, BannerHither logs the failure and macOS
behaves as it normally would; nothing else is affected. *Copy Diagnostics* dumps the current
NotificationCenter window attributes so such changes can be diagnosed from a bug report.

### Tested macOS versions

| macOS | Status |
| --- | --- |
| 26.6 (Tahoe) | Verified: banner window found, moved, and restored across NotificationCenter restarts |
| 14.0 – 15.x | Builds and should work (the window structure has been stable since Big Sur), but not verified yet |

### Known limitations

- If the target display is narrower than the display the banner window was sized for, the window
  extends past the display's left edge. The banner itself stays fully visible; the
  `resizeToTargetScreen` option below resizes the window first if that ever matters.
- Displays that mirror another display are not separate targets.
- Not tested with *Displays have separate Spaces* turned off, with Stage Manager, or on the lock screen.

## FAQ

**Why do my notifications appear on the wrong monitor?**
macOS shows notification banners on the primary display only, the one that carries the menu bar in
System Settings › Displays, no matter where your mouse pointer or your active window is. When you
work on another screen, every notification lands on the wrong screen. BannerHither moves each banner
to the display you are actually looking at.

**Can I get notifications on my second monitor or external display?**
Yes. Choose *Screen under the mouse pointer* or *Screen of the active window*, or pick the external
display as a fixed target. Banners then show up on the second monitor without changing anything else
about your setup.

**Why not just drag the menu bar to the other display in System Settings › Displays?**
That makes the other display the primary display, which also moves the Dock, the default position of
new windows and the primary Space, and it is a fixed choice that does not follow you when you switch
screens. BannerHither leaves your display arrangement alone and only moves the banner.

**Does it change the notification itself?**
No. The whole NotificationCenter window is moved, so clicking, swiping and notification actions keep
working, and the notification contents are never read. The Notification Center panel you open from
the clock is left untouched.

**Which macOS versions are supported?**
macOS 14 Sonoma or later, verified on macOS 26 Tahoe (see the tested versions table above).

## Advanced settings

Everything in the menu is stored in `UserDefaults` under `io.github.kjeon10.BannerHither`. Three
options have no menu item:

| Key | Default | Meaning |
| --- | --- | --- |
| `pollIntervalMilliseconds` | `1000` | Safety-net polling interval. Accessibility events drive the app; polling only covers missed events and NotificationCenter restarts. `0` disables polling (50–5000 accepted). |
| `resizeToTargetScreen` | `false` | Resize the banner window to the target display before moving it. |
| `updateFeedURL` | unset | Alternative release feed with the same JSON shape as GitHub's `releases/latest`, e.g. a local file, to test the update check. Read once at launch. |

```sh
defaults write io.github.kjeon10.BannerHither pollIntervalMilliseconds -int 500
defaults write io.github.kjeon10.BannerHither resizeToTargetScreen -bool true
```

Changes take effect on the next banner. To follow what the app is doing:

```sh
log stream --predicate 'subsystem == "io.github.kjeon10.BannerHither"' --level debug
```

## Building from source

Requirements: macOS 14 or later and Xcode 16 or later (or the matching Command Line Tools).

```sh
git clone https://github.com/KJeon10/BannerHither.git
cd BannerHither
make build          # → build/BannerHither.app
open build/BannerHither.app
```

Allow the Accessibility permission when the app asks for it, and you are done.

## Privacy

BannerHither never reads notification contents. Its only network request is the update check: with your
consent once a day, and whenever you choose *Check for Updates…*, it fetches the latest release number from
`api.github.com`. The request identifies the app and its version and nothing else; like any HTTPS connection
it shows GitHub your IP address. Automatic checks stay off until you allow them and can be switched off again
in the menu. If you prefer, you can [build it from source](#building-from-source) yourself.

## Credits

[PingPlace](https://github.com/NotWadeGrimridge/PingPlace), [ShoveIt](https://github.com/JaysonRawlins/ShoveIt) and [NotificationNanny](https://github.com/chessper53/NotificationNanny) served as references.

## License

[MIT](LICENSE) © 2026 [KJeon10](https://github.com/KJeon10)
