# NOX

A personal, offline-first WHOOP strap companion for iPhone — an independent fork of the open-source **NOOP** project, rebranded and maintained for personal use.

> **Unofficial & independent.** Not affiliated with, endorsed by, or sponsored by WHOOP, Inc. "WHOOP" is used only to identify the third-party hardware this app interoperates with. See [`DISCLAIMER.md`](DISCLAIMER.md) for the full legal notice.

## What is this?

NOX connects directly to a WHOOP 4.0 or 5.0/MG strap over Bluetooth — no WHOOP app, no account, no cloud. It reads the strap's raw sensor data and computes its own recovery, strain, and sleep scores **entirely on-device**, using published, peer-reviewed sports-science methods. Nothing is uploaded anywhere unless you explicitly choose to (e.g. the optional Home Assistant integration, which only ever talks to a Home Assistant instance you configure yourself).

This is a **personal build**: it targets iOS only, is distributed unsigned for sideloading via [SideStore](https://sidestore.io)/AltStore, and is not published on the App Store.

## Features

- **Direct BLE connection** to WHOOP 4.0 and 5.0/MG straps — no official app required
- **On-device Charge, Effort, and Rest scoring** (WHOOP's Recovery/Strain/Sleep, computed independently, same 0–100 scale)
- **Apple Watch as sensor** — run without a strap at all, using the Watch's own HealthKit data
- **Oura ring support**, standard/Garmin/Huami heart-rate bands, and generic Bluetooth fitness machines (FTMS)
- **Full offline backup & restore** to a folder of your choice (iCloud Drive, Dropbox, Google Drive, etc.)
- **Home Assistant integration** — optionally push your scores as sensors to your own Home Assistant instance for automations and dashboards
- **AI Coach** — optional, bring-your-own-key chat coach (Anthropic, OpenAI, Gemini, or any OpenAI-compatible local server)
- **Siri Shortcuts & App Intents**, Live Sessions, sleep staging, a personal lab notebook, mood/behaviour correlation tracking, and more
- **English and Spanish** localization

## Installation

NOX is not on the App Store. Install it via [SideStore](https://sidestore.io) or AltStore using this source URL:

```
https://raw.githubusercontent.com/Josemihumanes/NOX_JMH/main/altstore-source.json
```

Builds are unsigned `.ipa`s produced by GitHub Actions on every tagged release; SideStore/AltStore sign them locally with your own (free) Apple ID when you install.

## Building from source

The project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) — the `.xcodeproj` is generated from [`project.yml`](project.yml), not committed:

```bash
brew install xcodegen
xcodegen generate
xcodebuild -scheme NOOPiOS -configuration Release \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  clean build
```

See [`.github/workflows/ios-release.yml`](.github/workflows/ios-release.yml) for the exact release process.

## Not a medical device

Charge, Effort, Rest, and every other metric NOX computes are approximations for personal insight and curiosity — not clinically validated, not medical advice, and not a substitute for professional care. See [`DISCLAIMER.md`](DISCLAIMER.md) §5 for the full notice.

## License & attribution

Original work is licensed under the **PolyForm Noncommercial License 1.0.0** — see [`LICENSE`](LICENSE). Third-party dependencies keep their own licenses; see [`NOTICE`](NOTICE) and [`ATTRIBUTION.md`](ATTRIBUTION.md).
