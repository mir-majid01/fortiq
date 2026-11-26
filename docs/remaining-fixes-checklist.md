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

## Real previews and game links

- [ ] Add cached remote preview widget with loading/error/retry states.
- [ ] Never use procedural art as a real-base substitute.
- [ ] Add release Android `INTERNET` permission.
- [ ] Pass official Clash share URLs unchanged.
- [ ] Add browser/copy/store fallback without claiming in-game import success.
- [ ] Test image loading/cache/errors and URL forwarding.

## Taxonomy and Collections

- [ ] Map source categories explicitly and preserve original values.
- [ ] Keep unknown classifications unclassified.
- [ ] Add defensive tags only with source evidence/documented process.
- [ ] Verify real-entry search/filter/sort and empty states.
- [ ] Verify favourite persistence, duplicates, unfavourite, and missing entries.

## In-app updater

- [x] Design approved and published.
- [x] Implementation plan published and queued.
- [ ] Add release metadata service and semantic/build comparison.
- [ ] Add detailed update page: current/latest version, date, size, checksum, patch notes.
- [ ] Add real streamed download progress, speed/ETA, cancel, retry, and checksum verification.
- [ ] Add Android package-installer handoff and iOS App Store explanation.
- [ ] Add offline/rate-limit/no-release/checksum/install error recovery.
- [ ] Add updater service/widget/navigation tests.
- [ ] Add tagged GitHub Release workflow for APK + `.sha256` + notes.

## Final verification and delivery

- [x] `flutter analyze --no-fatal-infos`: 0 errors, 0 warnings.
- [x] Full `flutter test`: 167 tests green.
- [x] Golden comparisons pass against the approved sample/reference renders.
- [x] Build and validate debug APK: CRC clean, 195,208,931 bytes, SHA-256 recorded.
- [ ] Publish a new private test APK for remote device testing.
- [x] Device-check branded splash, persisted onboarding, three-tab nav, and honest empty catalogue state on Infinix X6876.
- [ ] Device-check favourites, links, previews, and updater when their implementations are available.
- [ ] Publish a public APK only if the rights gate passes.
- [x] Update `HANDOVER.md` with exact evidence and remaining limitations.
