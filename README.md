# Fortiq

Fortiq is a Flutter Android/iOS app for discovering Clash of Clans base layouts. It preserves a dark, gold-accented interface with Home, Explore, Collections, base details, filters, and native game-link handoff.

## Repository status

This repository is being organized during a maintenance pass. The current priorities are:

- Native Android/iOS Fortiq splash branding and launcher icons.
- Persistent onboarding and favourites.
- Removal of fabricated Community/Profile UI.
- A rights-gated real catalogue pipeline with real previews and unchanged Clash share links.
- An in-app updater backed by public GitHub Releases.

The app is unofficial and is not endorsed by or affiliated with Supercell or Clash of Clans.

## Important content-rights notice

The upstream `nschmeller/clash-bases` repository contains 5,162 catalogue records with remote preview URLs. Its MIT licence covers the upstream software/documentation, but the audit did not establish redistribution permission for all third-party preview images or catalogue content. Upstream also warns against bulk import without permission.

Therefore, the rights-uncleared catalogue JSON and the upstream clone are intentionally excluded from this public repository. Production must enable only entries with documented permission. No APK containing unresolved third-party catalogue content should be published as a public release until that rights review is complete.

See [NOTICE.md](NOTICE.md) and [the audit](docs/audit-2026-11-26.md).

## Project layout

- `fortiq/` — Flutter application source and tests.
- `reference/` — approved HTML/SVG design exports.
- `shots/` — reference renders used for visual comparison.
- `docs/` — audit, maintenance plan, and delivery notes.

## Local development

Requirements: Flutter 3.50.1+, Dart 3.14+, Android Studio/SDK, and Xcode for iOS builds.

```bash
cd fortiq
flutter pub get
flutter analyze --no-fatal-infos
flutter test
flutter build apk --debug
```

The rights-uncleared catalogue asset is omitted from the public source snapshot. Until the rights-gated catalogue migration lands, use the existing sample repository only for local UI/reference tests; never present it as real production data.

## Releases and APK downloads

Public APKs will be attached to GitHub Releases after the rights review and final verification. The in-app updater will read the latest public release, show version/patch-note/file-size details, download with progress, verify its checksum, and hand the APK to Android's package installer.

Repository: <https://github.com/mir-majid01/fortiq>
