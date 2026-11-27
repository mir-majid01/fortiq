# Fortiq Remaining Fixes Checklist

**Updated:** 2026-11-27 (second pass: TH19, Builder Base, preview speed)  
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

## Real catalogue (rights manifest + packaged export)

- [x] Add per-source rights manifest and lossless source metadata model.
- [x] Decode Home/Builder village from the official link payload; never guess Builder Hall level.
- [x] Preserve source type, tags, description, attribution, image URL, link, and added date.
- [x] Clear the `clash-bases` source for content and previews under its MIT licence, retaining attribution and the unofficial disclosure.
- [x] Add `tool/build_catalogue.py`, which validates the upstream export and writes the versioned `assets/data/cleared_catalogue.json`.
- [x] Package **5,345** real bases (5,194 Home Village TH4–TH19, 151 Builder Base BH4–BH10); production no longer shows an empty catalogue.
- [x] Add the BaseMelon source (TH19 + Builder Hall layouts) to the rights manifest as a second cleared source: metadata and official links only, previews hotlinked, project-owner approval recorded.
- [x] Fix village decoding: `HV`/`WB` are Home Village, `BB`/`BB2` are Builder Base, and the Builder Hall level comes from the `BB2` payload — the Builder Base section never lists Home Village layouts.
- [x] Scope the Builder feed strictly to the selected Builder Hall and show an explicit empty state for halls with no official links (BH3).
- [x] Fail the APK build if the packaged catalogue is empty, has duplicate IDs, includes an uncleared source, has a record without an HTTPS thumbnail, or packages a multi-megabyte preview without a lightweight rendition.
- [x] Fail the build on duplicate/malformed records instead of silently dropping them at runtime.
- [x] Keep the legacy `clash_bases_catalog.json` out of the repository and APK packaging.
- [x] Final audit: 5,345 records; 5,345 cleared; 5,345 valid official links; unique id/link/image; every sampled preview host and thumbnail rendition returned HTTP 200.
- [x] Ship a lightweight thumbnail rendition per record (host renditions where available, public weserv.nl resize proxy for the 67 multi-megabyte originals) and decode grid cards at the painted size.

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

- [x] `flutter analyze --no-fatal-infos`: 0 errors, 0 warnings, info-level diagnostics only.
- [x] Full `flutter test`: 246 non-golden tests green (goldens excluded from CI; all nine pass locally — the Home hall strip was regenerated for TH19 and every other golden is pixel-identical).
- [x] Golden comparisons pass against the approved sample/reference renders.
- [x] Trigger GitHub CI and validate the new debug APK/checksum: run 45966907616, 170,460,516 bytes, SHA-256 `51f2088356b1771e03874cdd27ea5041304eb632b56b1397ccc445a6b1314542`; packaged catalogue verified at 5,162 bases (first live-catalogue build).
- [x] Publish and verify private test build 6 (real catalogue): <https://github.com/mir-majid01/fortiq-test-builds/releases/tag/v0.1.2-test6> — 170,460,516 bytes, SHA-256 `55c13b79121b1c011dbc6aa16f28620aa0544e6426ca67ddebd35cca228b01df`.
- [x] Publish and verify private test build 5: <https://github.com/mir-majid01/fortiq-test-builds/releases/tag/v0.1.1-test5>.
- [x] Historical private test build 4: CRC clean, 195,208,931 bytes, SHA-256 recorded: <https://github.com/mir-majid01/fortiq-test-builds/releases/tag/v0.1.0-test4>.
- [x] Device-check branded splash and persisted onboarding on Infinix X6876.
- [x] Device-check the earlier honest empty catalogue state (now superseded by the packaged real catalogue).
- [ ] Device-check the real catalogue, favourites, links, previews, import, and updater when a live Mobile Use/Canvas surface is available.
- [x] Record current device-tool boundary: Mobile Use inventory and doctor both report zero live Canvas surfaces/broker records; no raw-ADB bypass used.
- [ ] Publish a public APK after the current release check.
- [x] Update `HANDOVER.md` with exact evidence and remaining limitations.
