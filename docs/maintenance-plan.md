# Fortiq Maintenance and Real Catalogue Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix native launch branding and persistence, remove fabricated social/profile UI, and add a rights-gated real Clash of Clans catalogue pipeline without redesigning the approved Fortiq interface.

**Architecture:** Keep the existing `AppState`/repository/`TabPage` architecture. Add a small persistent local-store service, a rights-aware catalogue model/mapper, a reusable remote-preview widget, and explicit source attribution. Retain `SampleBaseRepository` and `BasePreview` only for reference goldens/tests; production must not present samples as real bases.

**Tech Stack:** Flutter 3.50.1/Dart 3.14, Android/iOS, `shared_preferences`, `flutter_native_splash`, `cached_network_image`, existing `url_launcher` and `share_plus`.

**Spec:** `C:\Users\HP\.qoder\tmp\C--Users-HP-Desktop-Fortiq\attachments\be5d833f-6e2d-4a5b-ba78-7dcfe4e05aca\47041aa3-c880-499d-a87a-c219f9d42740.txt`

**Audit evidence:** `C:\Users\HP\Desktop\Fortiq\HANDOVER.md` plus the Phase 1 findings recorded in the session on 2026-11-26.

## Global Constraints

- Preserve the approved dark/gold UI, card/grid/detail geometry, typography, and bottom-nav visual style.
- Never fabricate base names, layouts, links, ratings, copy counts, creators, verification, follower counts, or defensive tags.
- Never present a procedural illustration as a real base preview.
- Do not bulk-enable third-party catalogue content or previews without documented redistribution permission.
- Preserve original source categories/tags/attribution and expose unknown classifications as unknown.
- Pass official Clash share URLs unchanged; launching a link must not be described as successful in-game import.
- Persist onboarding, favourites, and any retained follows with versioned local keys.
- No commits, pushes, dependency removal, or destructive operations unless explicitly requested.
- Run gates exactly as CI would: `flutter analyze --no-fatal-infos`, full `flutter test`, debug APK build.

---

## Phase 2 — Critical fixes

### Task 1: Native launch branding and continuous splash

**Files:**
- Modify: `fortiq/pubspec.yaml`
- Modify: `fortiq/lib/main.dart`
- Modify: `fortiq/android/app/src/main/AndroidManifest.xml`
- Modify: `fortiq/android/app/src/main/res/values/styles.xml`
- Modify: `fortiq/android/app/src/main/res/drawable/launch_background.xml`
- Modify: `fortiq/android/app/src/main/res/drawable-v21/launch_background.xml`
- Create: `fortiq/android/app/src/main/res/values-v31/styles.xml`
- Modify: `fortiq/ios/Runner/Base.lproj/LaunchScreen.storyboard`
- Modify: `fortiq/ios/Runner/Base.lproj/Main.storyboard`
- Modify: `fortiq/ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json`
- Create: canonical vector/PNG derivatives under `fortiq/assets/branding/`

**Interfaces:**
- Consumes: exact inline SVG paths from `reference/Splash.dc.html:18-27` and existing `FortiqEmblem` geometry.
- Produces: branded native launch assets and a native splash held until Flutter's first branded frame.

- [ ] Add a regression/configuration test asserting Android launch/normal backgrounds are `#0B0D10`, API 31+ splash resources exist, iOS launch background is dark, and no stock Flutter launcher assets remain.
- [ ] Extract the exact supplied SVG paths into a canonical asset; generate transparent padded PNG derivatives for legacy Android, Android 12+, iOS, and launcher icons. Do not invent a new logo.
- [ ] Add and configure `flutter_native_splash`:

```yaml
flutter_native_splash:
  color: "#0B0D10"
  color_dark: "#0B0D10"
  image: assets/branding/fortiq_splash.png
  image_dark: assets/branding/fortiq_splash.png
  android_gravity: center
  ios_content_mode: center
  fullscreen: true
  android_12:
    color: "#0B0D10"
    color_dark: "#0B0D10"
    image: assets/branding/fortiq_splash_android12.png
    image_dark: assets/branding/fortiq_splash_android12.png
```

- [ ] Generate native resources, replace stock launcher icons, set Android label to `Fortiq`, and verify API 31+ icon safe-zone padding.
- [ ] Preserve the native splash until app initialization completes, then remove it only when the first Flutter frame uses the same logo/background:

```dart
final binding = WidgetsFlutterBinding.ensureInitialized();
FlutterNativeSplash.preserve(widgetsBinding: binding);
await initializeFortiq();
runApp(const FortiqApp());
FlutterNativeSplash.remove();
```

- [ ] Build and inspect Android launch resources; cold-start test on Android 11 and Android 12+ when a device is available.

### Task 2: Persistent onboarding and local-store service

**Files:**
- Modify: `fortiq/pubspec.yaml`
- Create: `fortiq/lib/core/storage/local_store.dart`
- Modify: `fortiq/lib/app/state/app_state.dart`
- Modify: `fortiq/lib/app/app.dart`
- Modify: `fortiq/lib/main.dart`
- Create/Modify: `fortiq/test/persistence_test.dart`
- Modify: `fortiq/test/widget_test.dart`

**Interfaces:**
- Consumes: `SharedPreferences`.
- Produces: `LocalStore.loadOnboardingComplete()`, `completeOnboarding()`, `loadFavouriteIds()`, `saveFavouriteIds()`, with versioned keys.

- [ ] Write failing tests using `SharedPreferences.setMockInitialValues({})` for first launch, completion, recreated `AppState`, and normal restart routing.
- [ ] Add `shared_preferences` and implement a narrow `LocalStore` service:

```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setBool('fortiq.onboarding.completed.v1', true);
final ids = prefs.getStringList('fortiq.favourites.ids.v1') ?? <String>[];
```

- [ ] Load persisted state before choosing the root phase. `onboarded == false` shows onboarding; `true` opens MainShell after splash.
- [ ] Mark completion only from the existing finished callback used by Finish/Skip, await persistence, then transition.
- [ ] Test force-stop/process-recreation behavior at the state/service level and add a device cold-start check.

### Task 3: Remove Profile and fabricated Community; persist favourites

**Files:**
- Modify: `fortiq/lib/app/tabs.dart`
- Modify: `fortiq/lib/app/router.dart`
- Modify: `fortiq/lib/core/widgets/app_bottom_nav.dart`
- Modify: `fortiq/lib/features/home/home_screen.dart`
- Modify: `fortiq/lib/app/state/app_state.dart`
- Delete: `fortiq/lib/features/profile/profile_screen.dart`
- Delete or disable: `fortiq/lib/features/community/community_screen.dart`
- Modify: `fortiq/test/app_flows_test.dart`
- Modify: `fortiq/test/secondary_tabs_test.dart`
- Modify: `fortiq/test/home_controls_test.dart`
- Modify: `fortiq/test/widget_test.dart`

**Interfaces:**
- Consumes: `LocalStore` favourite IDs.
- Produces: three-tab production navigation (Home/Explore/Collections), no fake creator profiles, persistent favourite set.

- [ ] Add failing navigation tests asserting no Profile item/screen and no Community item when no genuine creator dataset is enabled.
- [ ] Remove Profile tab, route, nav item, and Home profile affordance. Preserve nav pill/item styling and indices 0–2.
- [ ] Remove fabricated Community creators and Follow UI. Do not convert upstream `builder` credits into profiles.
- [ ] Restore favourites from `LocalStore` before edits; write on toggle; keep IDs unique with `Set<String>`.
- [ ] Handle stale favourite IDs explicitly in Collections with an unavailable-entry state rather than dropping them silently.
- [ ] Update responsive navigation tests from five items to three and regenerate affected goldens.

---

## Phase 3 — Rights-gated real catalogue, previews, and links

### Task 4: Rights-aware catalogue model and lossless mapper

**Files:**
- Modify: `fortiq/lib/data/models/base_layout.dart`
- Create: `fortiq/lib/data/models/catalogue_rights.dart`
- Create: `fortiq/assets/data/catalogue_rights.json`
- Modify: `fortiq/lib/data/sources/clash_bases_source.dart`
- Modify: `fortiq/lib/data/repositories/base_repository.dart`
- Modify: `fortiq/lib/data/repositories/queries.dart`
- Create/Modify: `fortiq/test/real_catalogue_test.dart`
- Modify: `fortiq/test/data_test.dart`

**Interfaces:**
- Consumes: upstream `bases.json` fields `id`, `name`, `town_hall`, `type`, `link`, `description`, `builder`, `tags`, `added`, `image`.
- Produces: entries with `sourceCategories`, `sourceTags`, `sourceAttribution`, `sourceUrl`, `addedAt`, `imageUrl`, `gameLink`, `village`, nullable hall level, and rights status.

- [ ] Add failing tests asserting 5,162 unique source records, exact URL forwarding, no duplicate IDs/links/images, source tags preserved, and no fabricated ratings/copies/verification.
- [ ] Add a per-source rights manifest. Current evidence clears **zero** third-party sources for bulk content/preview redistribution; unresolved records must be excluded from production.
- [ ] Keep sample data test-only. Production repository returns only rights-cleared records; when none are cleared, show an honest catalogue-unavailable state rather than samples.
- [ ] Decode village from the documented OpenLayout payload (`HV`/`WB`); never infer Builder Hall level from `town_hall` without evidence. Unknown hall remains unknown.
- [ ] Preserve original `type`, `tags`, `builder`, `added`, and source URL. Map categories only through an explicit table; unknown values remain unclassified.
- [ ] Retain MIT notice and add an unofficial/no-endorsement disclosure. Do not scrape, hotlink, or cache unresolved previews.

### Task 5: Real preview widget and honest deep-link fallback

**Files:**
- Create: `fortiq/lib/core/widgets/base_preview_image.dart`
- Modify: `fortiq/lib/features/base_preview/base_preview.dart` (sample/golden compatibility only)
- Modify: Detail, Home, Explore, and Collections preview call sites
- Modify: `fortiq/lib/core/widgets/game_actions.dart`
- Modify: `fortiq/android/app/src/main/AndroidManifest.xml`
- Modify: `fortiq/test/preview_image_test.dart`
- Modify: `fortiq/test/game_actions_test.dart`
- Modify: `fortiq/test/app_flows_test.dart`

**Interfaces:**
- Consumes: rights-cleared `imageUrl` and `gameLink`.
- Produces: cached real previews with loading/error/retry states; unchanged external link launch with browser/copy/store fallback.

- [ ] Add `INTERNET` to the release manifest.
- [ ] Add `cached_network_image` and implement a reusable preview:

```dart
CachedNetworkImage(
  imageUrl: entry.imageUrl,
  fit: BoxFit.cover,
  placeholder: (_, _) => const FortiqPreviewPlaceholder(),
  progressIndicatorBuilder: (_, _, progress) =>
      FortiqPreviewPlaceholder(progress: progress.progress),
  errorWidget: (_, _, _) => FortiqPreviewError(onRetry: retry),
)
```

- [ ] Never fall back to procedural art for a real entry. Missing/uncleared previews show an explicit unavailable state.
- [ ] Pass `gameLink` unchanged to `launchUrl(..., mode: LaunchMode.externalApplication)`.
- [ ] On false/exception, offer Open in browser, Copy link, and Get Clash of Clans; never claim the layout was imported.
- [ ] Test image loading/error/retry/cache behavior and URL forwarding with escaped/query-containing links.

---

## Phase 4 — Taxonomy and Collections

### Task 6: Evidence-based taxonomy, filtering, and saved-base lifecycle

**Files:**
- Modify: `fortiq/lib/data/models/filters.dart`
- Modify: `fortiq/lib/data/repositories/queries.dart`
- Modify: `fortiq/lib/features/filters/filters_sheet.dart`
- Modify: `fortiq/lib/features/collections/collections_screen.dart`
- Modify: `fortiq/test/real_catalogue_test.dart`
- Modify: `fortiq/test/filters_sheet_test.dart`
- Modify: `fortiq/test/app_flows_test.dart`

**Interfaces:**
- Consumes: preserved source type/tags/description and rights-cleared entries.
- Produces: primary category filters, optional defensive tags, unknown/unclassified state, and persistent Collections.

- [ ] Map explicit source values only: `War → War`, `Farm → Farming`, `Trophy → Trophy`, `Hybrid → Hybrid`; preserve originals. `Home Village`, `Progress`, and `Fun` remain unclassified unless documented evidence supports a mapping.
- [ ] Add CWL/Legend/Anti-2/Anti-3/Ranked only where source tags/descriptions explicitly support them.
- [ ] Add defensive architecture tags as extensible metadata; do not infer counters from images or names without a documented classification process.
- [ ] Ensure filters/search/sort operate on real entries and preserve unknown classifications.
- [ ] Show useful empty states for zero rights-cleared entries, no filter matches, and stale favourite IDs.
- [ ] Test no duplicate favourites, persistence after AppState recreation, unfavourite, and missing-catalogue entries.

---

## Phase 5 — Verification and delivery

### Task 7: Full regression, build, and device validation

**Files:**
- Modify: affected tests/goldens
- Modify: `HANDOVER.md`

- [ ] Run `flutter analyze --no-fatal-infos`; require 0 errors and 0 warnings.
- [ ] Run full `flutter test --reporter expanded`; require all tests passing.
- [ ] Recalculate and report rights-cleared entry count, usable preview count, structurally valid link count, and excluded count.
- [ ] Build `app-debug.apk` and validate ZIP CRC plus required Android entries.
- [ ] Reconnect an Android device and test cold start, onboarding skip after restart, three-tab navigation, real-entry availability, image loading/failure, and Open in Game handoff/fallback.
- [ ] Record unresolved licensing limits and unavailable functionality honestly in `HANDOVER.md`.

## Execution Note

The user requested autonomous continuation. Execute inline task-by-task, but stop only for a genuine rights/permission blocker or unavailable device. Do not enable unresolved catalogue content merely to make the app appear complete.
