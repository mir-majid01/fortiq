# Fortiq Remaining Fixes Checklist

**Updated:** 2026-11-26  
**Execution rule:** complete each item with tests/analyzer, review it, update the handover, then continue. No fake production data or rights-uncleared public release.

## Confirmed / complete

- [x] Native Fortiq splash, launcher icon, dark Android/iOS launch surfaces, Android 12 safe-zone scale, and canonical image tests.
- [x] Onboarding completion persists across relaunch — confirmed by the user on the physical device.
- [x] Public source repository, issue tracker, design/audit docs, and private remote-test APK channel.

## Complete

- [x] Remove Profile and fabricated Community/fake Follow UI.
- [x] Reduce production bottom navigation to Home / Explore / Collections.
- [x] Persist favourites and handle stale/unavailable favourite IDs.
- [x] Update navigation, favourites, responsive, and golden tests.

## Rights-gated real catalogue

- [x] Add per-source rights manifest and lossless source metadata model.
- [x] Decode Home/Builder village from the official link payload; never guess Builder Hall level.
- [x] Preserve source type, tags, description, attribution, image URL, link, and added date.
- [x] Enable only records with documented permission; current cleared count is zero.
- [x] Production shows an honest unavailable state instead of sample/fake bases.
- [x] Keep full unresolved JSON out of the public repository and APK packaging.
- [x] Final audit: 5,162 upstream records; 0 rights-cleared; 0 usable cleared previews; 5,162 valid official links; 5,162 excluded unresolved.

## Real previews and game links

- [x] Add cached remote preview widget with loading/error/retry states.
- [x] Never use procedural art as a real-base substitute.
- [x] Add release Android `INTERNET` permission.
- [x] Pass official Clash share URLs unchanged.
- [x] Add browser/copy/store fallback without claiming in-game import success.
- [x] Test image loading/cache/errors, compact error layout, and URL forwarding.

## Taxonomy and Collections

- [x] Map source categories explicitly and preserve original values.
- [x] Keep unknown classifications unclassified.
- [x] Add defensive tags only with source evidence/documented process.
- [x] Verify real-entry search/filter/sort and empty states.
- [x] Verify favourite persistence, duplicates, unfavourite, and missing entries.
- [x] Scope real Home feeds to the selected hall and add catalogue loading feedback.
- [x] Add direct unsave to available Collections cards.

## In-app updater

- [x] Design approved and published.
- [x] Implementation plan published and queued.
- [x] Add release metadata service and semantic/build comparison.
- [x] Add detailed update page: current/latest version, date, size, checksum, patch notes.
- [x] Add real streamed download progress, speed/ETA, cancel, retry, and checksum verification.
- [x] Add Android package-installer handoff and iOS App Store explanation.
- [x] Add offline/rate-limit/no-release/checksum/install error recovery.
- [x] Add updater service/widget/navigation tests.
- [x] Add tagged GitHub Release workflow for APK + `.sha256` + notes behind the rights-approval variable.

## Lawful user import

- [x] Parse only official HTTPS OpenLayout links and preserve the original URL.
- [x] Require a user-owned preview and copy it into app-private storage.
- [x] Persist imported metadata with a versioned local key across relaunch.
- [x] Merge imports with rights-cleared records and reject duplicate content.
- [x] Add Explore empty-state import entry and validation/persistence tests.

## Final verification and delivery

- [x] `flutter analyze --no-fatal-infos`: 0 errors, 0 warnings, 133 retained infos.
- [x] Full `flutter test`: 239 tests green.
- [x] Golden comparisons pass against the approved sample/reference renders.
- [x] Trigger GitHub CI and validate the new debug APK/checksum: run 45959058351, 170,117,716 bytes, SHA-256 `c8143fdfd9782e9f6a8de41cf34e09e8eaab5ec1ceb0f21791a1d38fd139bc14`.
- [x] Publish and verify private test build 5: <https://github.com/mir-majid01/fortiq-test-builds/releases/tag/v0.1.1-test5>.
- [x] Historical private test build 4: CRC clean, 195,208,931 bytes, SHA-256 recorded: <https://github.com/mir-majid01/fortiq-test-builds/releases/tag/v0.1.0-test4>.
- [x] Device-check branded splash, persisted onboarding, three-tab nav, and honest empty catalogue state on Infinix X6876.
- [ ] Device-check favourites, links, previews, import, and updater when a live Mobile Use/Canvas surface is available.
- [x] Record current device-tool boundary: Mobile Use inventory and doctor both report zero live Canvas surfaces/broker records; no raw-ADB bypass used.
- [ ] Publish a public APK only if the rights gate passes.
- [x] Update `HANDOVER.md` with exact evidence and remaining limitations.
