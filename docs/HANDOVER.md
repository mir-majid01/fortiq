# FORTIQ — Flutter Implementation Handover

**Read this fully before touching code.** It contains the product context, the
approved design contract, the architecture, the completed implementation state,
and the final verification evidence.

---

## 1. What we are building

**Fortiq** is a real Flutter mobile app (Android + iOS) for discovering Clash
of Clans base layouts. The approved design already exists as 7 HTML artboards
exported from a design tool — you are **implementing, not redesigning**.
Fidelity to those artboards is the acceptance bar.

The three sources of truth, all on disk:

| Path | What it is |
|---|---|
| `C:\Users\HP\Desktop\Fortiq\reference\` | The design export: `Splash.dc.html`, `Onboarding.dc.html`, `Main.dc.html` (Home), `Explore.dc.html`, `Filters.dc.html`, `Detail.dc.html`, `BasePreview.dc.html`, `canvas.json` (artboard notes). `_runtime/` is the export tool's JS — **not** part of the design. |
| `C:\Users\HP\Desktop\Fortiq\fortiq\` | The Flutter app (this is the deliverable). |
| `C:\Users\HP\Desktop\Fortiq\clash-bases\` | Local upstream audit copy only. Its 5,162-record `bases.json` is not packaged or published because third-party content/preview redistribution rights remain unresolved. |

Supporting artifacts: `C:\Users\HP\Desktop\Fortiq\shots\ref_*.png` are
headless-Chrome renders of the reference artboards;
`fortiq\test\goldens\*.png` are matching Flutter renders. Compare them
side-by-side (Read tool) to verify fidelity.

Public repository: <https://github.com/mir-majid01/fortiq>. Issues #1–#8 track
native branding, persistence, fake social/profile removal, rights-gated real
catalogue integration, previews/deep links, taxonomy/Collections, the in-app
updater, and final release verification. Public APKs must be distributed only
through GitHub Releases after the rights review passes.

Private remote-testing releases: <https://github.com/mir-majid01/fortiq-test-builds>.
These are personal debug builds and are not public rights-cleared releases.

### Maintenance update — 2026-11-26

- Native splash/logo/launcher work is complete and reviewed: 125 tests passed
  at that checkpoint, analyzer had 0 errors/0 warnings, and the Android 12 crest
  scale matches Flutter. Physical cold-start visuals remain unverified.
- SharedPreferences onboarding persistence is complete and reviewed: 142 tests
  passed, analyzer had 0 errors/0 warnings, and completion is read on cold start.
  The user confirmed on the physical device that onboarding no longer reappears
  after relaunch.
- Profile/fake Community removal and persistent favourites are complete and
  reviewed. Production navigation is Home / Explore / Collections; favourites
  persist through `shared_preferences` and stale IDs remain removable.
- The rights-gated catalogue mapper is complete and reviewed. Production uses
  `ClashBasesCatalogRepository`, preserves source metadata, detects only
  documented HV/WB payloads, rejects unsupported schemas/duplicates, and shows
  an honest unavailable state. Sample data is injected only by tests.
- Catalogue rights remain unresolved: zero upstream sources are cleared for
  third-party content/preview redistribution. The full 5,162-record JSON is not
  packaged or published; the app ships an empty cleared dataset and rights
  manifest.
- Final Task 4 verification: `flutter analyze --no-fatal-infos` exited 0 with
  0 errors/0 warnings; `flutter test --reporter expanded` passed 167 tests,
  including 19 rights-gated catalogue tests and all nine golden comparisons.
- The updater design is approved and published in `docs/updater-design.md` on
  the public repository; implementation is queued.

---

## 2. Environment (Windows, Git Bash)

```bash
# Flutter is NOT on PATH. Always call it like this:
export PUB_CACHE=/c/flutter-sdk/.pub-cache
/c/flutter-sdk/flutter/bin/flutter.bat <command>
# (run from C:\Users\HP\Desktop\Fortiq\fortiq)
```

- Flutter **3.50.1 stable** (Dart 3.14) at `C:\flutter-sdk\flutter`. Do not
  prepend its `bin` to PATH — that shadows `head`/`sed` in Git Bash.
- Android SDK: `C:\Users\HP\AppData\Local\Android\Sdk` (licenses accepted;
  NDK 28.2.13676358 was auto-installed by Gradle).
- Java: `JAVA_HOME="C:\Program Files\Android\Android Studio\jbr"` (JBR 21) —
  set it for Gradle builds.
- First Gradle build downloads AGP/Gradle — needs network, takes ~5–15 min.
- Headless Chrome (for reference renders):
  `"C:\Program Files\Google\Chrome\Application\chrome.exe"`.
- Serve the reference folder for Chrome: `python -m http.server 8791` inside
  `C:\Users\HP\Desktop\Fortiq\reference` (scripts don't run from `file://`).

**Analyzer note:** Flutter 3.50 deprecates `package:flutter/material.dart` in
favor of `material_ui`. Every file emits an info-level
`deprecated_member_use`. **Leave these** — migrating is a separate decision,
not part of this handover. Current baseline: **0 errors, 0 warnings, 110
infos** (Flutter 3.50 deprecations, prefer-const suggestions, and existing
test/API deprecations). Use `flutter analyze --no-fatal-infos` for a successful
exit while retaining the required zero-error/zero-warning gate.

---

## 3. Architecture

Dependency-light by design: **no state-management or routing packages**.
Runtime dependencies are `flutter_native_splash`, `share_plus`,
`shared_preferences`, and `url_launcher`; dev dependencies include
`flutter_lints` and `image`. Fonts are bundled TTFs (no google_fonts).

```
fortiq/lib/
  main.dart                      # entry; sets SystemUiOverlayStyle
  app/
    app.dart                     # FortiqApp: splash → onboarding → MainShell (AnimatedSwitcher)
    router.dart                  # MainShell = IndexedStack of 3 tabs
    tabs.dart                    # AppTab constants (home/explore/collections)
    state/app_state.dart         # THE state container (ChangeNotifier) — see §4
    theme/
      app_colors.dart            # every colour token (values lifted from the HTML)
      app_typography.dart        # every TextStyle (Manrope = display, Inter = body)
      app_theme.dart             # ThemeData wiring
  core/
    icons/svg_path.dart          # minimal SVG path parser (M L H V C S Q T A Z, rel/abs)
    icons/fortiq_icons.dart      # all reference stroke icons as path data + FortiqIcon painter
    icons/fortiq_emblem.dart     # the 3-path gold shield logo painter
    widgets/
      state_scope.dart           # InheritedNotifier<AppState> → StateScope.of(context)
      buttons.dart               # PrimaryButton, GhostButton, OverlayIconButton(required label)
      chips.dart                 # PillChip, HallChip, SegmentedToggle, ToggleSwitch
      badges.dart                # HallBadge, HeartButton, PreviewScrim
      app_bottom_nav.dart        # floating pill nav (SafeArea-aware)
      tab_page.dart              # shared TabPage scaffold + nav used by all three tabs
      expanded_tap_area.dart     # NEW — 44×44 hit targets without visual change
      section_header.dart, creator_avatar.dart, game_actions.dart
  features/
    splash/, onboarding/, home/ (+widgets/), explore/ (+widgets/),
    filters/, base_detail/, base_preview/, collections/,
    shared/placeholder_tab.dart
  data/
    models/base_layout.dart      # BaseLayout, Creator, Village(+unknown), source metadata
    models/catalogue_rights.dart # fail-closed per-source redistribution evidence
    models/filters.dart          # ExploreFilters (village is `Village?` now), Freshness, BaseSort
    repositories/base_repository.dart  # interface + rights-gated production provider
    repositories/queries.dart    # queryBases(): filter + search + sort pipeline
    sources/sample_base_source.dart    # 86 HV + 18 BB test-only placeholder bases
    sources/clash_bases_source.dart    # cleared-catalogue loader + lossless mapper
```

### Rendering the base previews (critical to understand)

`features/base_preview/base_preview.dart` is a **Dart port of the design's
procedural generator** — the reference draws isometric bases with a seeded
LCG (`st=(seed*7919+12345)%233280; st=(st*9301+49297)%233280; st/233280`),
an iso projection `P(x,y,z)=[50+(x-y)*.66, 53+(x+y)*.66*.5−z]`, 4 themes
(`seed%4`), 6 building palettes, 3 wall rings, 16 trees, and a vignette.
The Dart port is **bit-compatible**: the same seed renders the same art.
Geometry is cached per seed (`PreviewGeometry.forSeed`). Tests assert exact
building/tree counts per seed against a Python replica. **Do not "improve"
the painter — any change breaks fidelity.** `BasePreview` fills its parent;
callers wrap in `ClipRRect`.

---

## 4. State & data flow

`AppState extends ChangeNotifier`, provided by `StateScope`
(`StateScope.of(context)`). Explore results are **memoised**
(`_results` invalidated by `_invalidateResults()` on any query/filter/sort/
data change) — never compute them inside build without the cache.

- **Search**: `AppState.searchController` (a `TextEditingController`) is the
  single source of truth. `setSearch(v)` also dismisses the keyboard;
  `clearSearch()` clears. `searchSuggestions` (names + creators) recomputed
  lazily.
- **Filters**: `AppState.filters` (an `ExploreFilters`). The sheet edits a
  `copy()` draft and commits via `applyFilters(draft)`. Quick chips mutate
  `filters` directly then call `notifyFilterChanged()`.
  **`ExploreFilters.village` is `Village?`** — `null` means *both villages*
  (the Explore "All" chip); `Village.home` is the default/first-paint state.
  `activeGroupCount` drives the Filters-button badge.
- **Home handoff**: `openExploreFromHome({category})` resets filters to the
  Home selection (village + hall level, optional category) and switches to
  the Explore tab. **Home no longer touches search.**
- **Village switching on Home** also swaps the feed: curated design content
  exists only for Home Village; Builder Base uses derived picks
  (`_builderFeed` best-rated, `_builderRecent` newest). Same layout, BB data.
- **Favourites**: a persistent `Set<String>` in AppState, restored before edits
  from `LocalStore`; writes are serialized and failures roll back optimistically
  changed state. `CollectionsScreen` renders saved bases and keeps stale IDs
  visible as removable unavailable entries. There is no follow state.
- **Production data source**: `repositoryProvider()` always returns
  `ClashBasesCatalogRepository`. It loads only records whose manifest source has
  explicit content and preview redistribution clearance. The current cleared
  count is zero, so Home/Explore show an honest unavailable state. The bundled
  sample repository is injected explicitly by reference/golden tests only.
- **Deep links**: real catalogue entries carry official
  `link.clashofclans.com` URLs → `GameActions.openInGame` launches via
  `url_launcher`. Sample bases have `gameLink == null` → an honest fallback
  bottom sheet (never fake success). Copy-link uses `Clipboard` + SnackBar;
  share uses `share_plus`.

---

## 5. Design contract (the fidelity rules)

Reference artboard: **390×844** (Home full-scroll artboard is 1500 tall).
Translate HTML → widgets. Never WebView, never screenshots, never redesign.

### Colour tokens (all in `app_colors.dart`, use them, never inline hex)
Background `#0B0D10` · Surface `#11151A` · Card `#171C23` · Gold `#D6A84F` ·
Gold-bright (emblem) `#E6BF68` · On-gold text `#14100A` · Text `#F2F4F7` ·
Secondary text `#929BA8` · Card-subtle text `#C9CFD8` · On-image text
`#E3E7ED` · Success `#6DAE8B` · Borders white @ .06/.07/.08/.10/.14 ·
Gold washes @ .10/.12/.18 · Nav bg `rgba(23,28,35,.96)` · Scrim `#050607` ·
Segment selected `#1E2530` (Home) / `#252D3A` (sheet) · Inactive chip
`#2A323D` · Badge backdrop `rgba(11,13,16,.8)`.

### Typography
**Manrope** (500/600/700/800 bundled) = headings, brand, prominent numbers.
**Inter** (400/500/600/700 bundled) = body, labels. Key styles (all pre-built
in `app_typography.dart`): brand wordmark 32/15/14px w800 with .2–.24em
tracking (optically centre with matching left padding); Explore title 24/800;
greeting 22/800; section titles 17/700 Manrope; card titles 15/600 Inter;
featured title 22/800; detail title 26/800 h1.1; onboarding 30/800 h1.12 +
15/400 h1.55 body; badges 11–12/700 tabular figures (`FontFeature.tabularFigures()`
wherever numbers align, e.g. "TH 17", "86 bases").

### Component geometry that must not drift
- Bottom nav: floating pill, h68, r20, inset 16 horizontal, **28px above
  bottom (or above the safe inset when larger)** — `AppBottomNav` handles
  this; 5 items, 22px icons, 11px labels, 4px active dot under label.
- Featured card h300 r16; trending card w256, image h192 r14; explore grid
  2 columns, gap 12h/14v, preview h166 r14, `childAspectRatio: 166/216`;
  recent rows: 72×72 thumb r10, card r14 bg surface.
- Chips: quick chips h34 r999 px14 13/600; hall chips h38 px14 r10 (sheet:
  56×36 r10); segmented toggles 3px-inset containers, 9px-radius segments.
- Filter sheet: top-rounded 20, bg surface, handle 36×4, groups labelled
  12/600 +1.2 tracking in `#929BA8`, fixed bottom action bar (Reset ghost +
  Show Results gold, both h52 r12), content scrolls, bar pinned.
- Detail: preview 470px full-bleed with 4-stop gradient
  (`rgba(11,13,16,.55)→transparent 20%→transparent 66%→#0B0D10 100%`),
  metadata block starts at y436 (overlaps gradient), zoom button right:20
  top:396, bottom bar = gold Open in Game (h54, flex) + 54×54 copy button.
- Previews always get scrims from `PreviewScrim` with the reference's exact
  stops (featured: .4/0/.5/.94 @ 0/.26/.58/1; trending: transparent→.8 @
  .62/1; onboarding: .3/0/.85 @ 0/.25/1).

### Pro-dev UI rules already established (keep them)
- **Touch targets**: the design uses 30–40px icon buttons. `OverlayIconButton`
  now requires a `label` (a11y) and wraps in `ExpandedTapArea.toTarget`
  (hit area padded to 44×44, visuals unchanged). Keep this pattern for any
  small control.
- **Safe areas**: content lives inside `SafeArea(bottom: false)`; the nav and
  sheet action bars use `SafeArea(top: false, minimum: ...)`. Scrollable
  content must pad its bottom by `TabPage.contentBottomPadding(context)`
  (= nav height + max(system inset, 28) + 24).
- **Keyboard**: tab scaffolds keep default `resizeToAvoidBottomInset: true`
  (search field stays visible); the filter sheet is `isScrollControlled` and
  internally scrollable.
- **Performance**: `const` constructors everywhere, memoised results,
  `RepaintBoundary` + `isComplex` on preview painters, geometry cache,
  list builders with separators, no rebuild storms (AppState notifies once
  per action).
- **A11y**: Semantics labels on all icon-only controls; `Semantics(button:
  true)` on text CTAs; chips/nav items are labelled.
- **Splash/Onboarding sizing**: splash positions are fractional
  (top 37.7% of height, bar at bottom 84); onboarding card stack scales by
  fraction of available space and the page switches to a scroll layout below
  600px height.

---

## 6. Known design inconsistencies and the resolutions taken (do not relitigate)

1. **TH levels per base differ between artboards** (Trending shows Hollow
   Crown TH16/Iron TH16/Ashfall TH15; Explore shows all TH17 under a TH17
   filter). → Canonicalised to **Explore** (all TH17) so the Filters state is
   logically consistent. Trending badges therefore read TH 17.
2. **Preview seeds differ between artboards** (Hollow Crown seed 5 in
   Trending vs seed 12 in Explore; Ashfall 11 vs 15). → One canonical seed
   per base (5, 8, 11). Same art everywhere for a given base.
3. **Featured subtitle**: reference reads "Anti 3 Star · by Kaiden" (the
   secondary tag) → implemented as `categories.last`.
4. **Detail stats "Updated 2d ago"** vs featured "New · 2h ago" for the same
   base → detail transforms `New · X` → `Updated X`.
5. **Explore reference shows only 4 results + 2 skeleton cards** (loading
   placeholders). The app shows the real (86) results; skeletons appear only
   while a source loads.
6. **Onboarding front-card art in the export renders seed 6's theme** (export
   runtime stacking quirk). Markup says front = seed 3 → we follow the markup
   (consistent Obsidian Ring art everywhere), back card = seed 6 at 50%.
7. **Onboarding pages 2–3 are not designed** (canvas says "1 of 3", 3 dots).
   Pages 2–3 exist with placeholder copy in the same voice — flagged in code.
8. **Standalone `BasePreview.dc.html` renders 2× zoomed** — export-runtime
   artifact. In-context usage (cards) is the ground truth and matches our
   painter exactly.
9. **The 1500px Home artboard keeps its fixed nav at the 844px viewport
   position** — an export-layout artifact. The app anchors the nav to the real
   viewport bottom, so `home_full.png` intentionally differs there.
10. **Explore's reference is a static mock** with an active-filter badge, a
    filled first heart, four results, and two skeleton cards. The app ships
    functional default state (no active badge, unfilled hearts, real results);
    skeletons appear only while loading.

---

## 7. CURRENT STATE — completed implementation

The §7.2 compile migration and the subsequent interaction/UI refactor are
complete. The app builds against the shared `AppState`/`TabPage` architecture;
the approved procedural painter and reference artboards were not modified.

### 7.1 State, navigation, and data
- `AppState` owns the shared search controller, memoised Explore results,
  village/hall invariants, filters, persistent favourites, three-tab selection,
  and disposal-safe catalogue loading with retry.
- `MainShell` retains Home / Explore / Collections in an `IndexedStack`; every
  tab uses `TabPage`, route-local `ScaffoldMessenger`, keyboard resizing,
  safe-area padding, and bottom-nav clearance.
- Home category/View-all handoffs open scoped Explore results without resetting
  shared search. Explore All/Home/Builder, TH/BH, category, sort, badge, and
  filter-draft behavior are covered by end-to-end tests.
- Production uses the rights-gated catalogue and currently has zero cleared
  entries. Sample data remains test-only and every generated entry is marked
  `isSample: true`. The unresolved 5,162-record JSON is not packaged.

### 7.2 Interactions, accessibility, and responsive behavior
- All icon controls have descriptive semantics and 44×44 hit targets without
  changing their approved visual dimensions. Chips, segmented tabs, switches,
  cards, recent rows, filters, and Detail actions have isolated state semantics.
- Copy/share/open-game actions report success, dismissal, unavailability, or
  the honest sample-link fallback exactly once. Share uses the invoking render
  box origin; copy uses the clipboard.
- Detail supports nullable real-catalogue stats, explicit source attribution,
  save state, fixed actions, and preview zoom. Missing style metadata does not
  render an empty chip. Filters support draft/reset/apply, a named close control,
  safe-area footer, and one whole-row verified switch.
- Default 390×844 geometry is preserved. Narrow widths and large text adapt the
  bottom nav, Explore toolbar, Detail CTA, Filters verified row, and segmented
  controls; segmented controls scroll only when scaled labels cannot fit.
- Filters uses the documented sheet segment color (`#252D3A`), compact group
  spacing, and a pinned 52px action row so all controls are visible at the
  reference artboard size while remaining scrollable at larger text sizes.

### 7.3 Verification coverage
- 14 end-to-end flow tests cover navigation, retained state, search handoff,
  filters, favourites, fallbacks, copy/share, zoom, retry, and disposal.
- Dedicated control, Detail, Home, Explore, Filters, secondary-tab, SVG, state,
  and golden tests cover semantics, touch edges, safe areas, and empty/error
  states.
- Five responsive tests cover 320px/2× text, landscape, short onboarding,
  compact Detail actions, and compact Filters.

---

## 8. Verification workflow (run in this order)

```bash
cd /c/Users/HP/Desktop/Fortiq/fortiq
export PUB_CACHE=/c/flutter-sdk/.pub-cache
FLUTTER=/c/flutter-sdk/flutter/bin/flutter.bat

# 1. Static analysis — must be 0 errors / 0 warnings (deprecation infos OK)
$FLUTTER analyze --no-fatal-infos

# 2. Tests — 167 green: preview/data/query/SVG/state tests, widget controls,
#    end-to-end flows, rights-gated catalogue, responsive/safe-area cases,
#    and all nine golden captures
$FLUTTER test

# 3. Re-capture Flutter renders for visual comparison
$FLUTTER test test/goldens_test.dart --update-goldens   # → test/goldens/*.png
```

Visual comparison protocol (do not skip):
1. Reference renders already exist in `C:\Users\HP\Desktop\Fortiq\shots\`
   (`ref_Splash/Onboarding/Main/Explore/Filters/Detail/BasePreview.png`).
   If missing, serve `reference/` on `:8791` and capture with headless Chrome:
   `chrome --headless=new --disable-gpu --hide-scrollbars
   --force-device-scale-factor=1 --window-size=390,844 --virtual-time-budget=5000
   --screenshot=<out.png> http://localhost:8791/<Artboard>.dc.html`
2. Read each pair of PNGs and diff: composition, spacing, typography,
   colours, radii, badge/chip geometry, nav placement, sheet layout, preview
   proportions. Fix mismatches in the Flutter code (never by editing the
   reference), then re-run steps 1–3.

### Final verification evidence — 2026-11-26 (Task 4)

- `flutter analyze --no-fatal-infos`: exit 0, **0 errors, 0 warnings, 110
  infos**. The Flutter 3.50 `material.dart` migration remains intentionally out
  of scope.
- `flutter test --reporter expanded`: exit 0, **167 tests passed**, including
  19 rights-gated catalogue tests and all nine golden comparisons.
- Direct Task 4 review found and fixed three real-entry edge cases: empty
  category captions no longer crash Home, source attribution is shown without a
  fabricated person, and missing style metadata no longer renders an empty chip.
  Unsupported catalogue schema versions now fail closed.
- `flutter build apk --debug`: exit 0.
  Artifact: `fortiq/build/app/outputs/flutter-apk/app-debug.apk`, **195,208,931
  bytes**, SHA-256
  `238638e8aabb15a774f1ba67a38815aba41e24faa8be8da9a7a1022b982898a6`.
- APK ZIP CRC validation passed. `AndroidManifest.xml`, `classes.dex`,
  `resources.arsc`, and `lib/arm64-v8a/libflutter.so` are present. The package
  contains `assets/data/catalogue_rights.json` and
  `assets/data/cleared_catalogue.json`; it does **not** contain
  `clash_bases_catalog.json`.
- Connected-device validation: installed successfully on Infinix X6876
  (`1541831584021235`). Home, Explore, and Collections were exercised through
  the real accessibility tree. Home/Explore show “Catalogue unavailable” and
  “No rights-cleared bases are available.” Collections shows its honest empty
  state. Onboarding remained completed after relaunch; no onboarding screen
  reappeared. The launch capture showed the branded Fortiq splash.

Android build (after everything is green):

```bash
cd /c/Users/HP/Desktop/Fortiq/fortiq
export JAVA_HOME="/c/Program Files/Android/Android Studio/jbr"
export PUB_CACHE=/c/flutter-sdk/.pub-cache
/c/flutter-sdk/flutter/bin/flutter.bat build apk --debug
# → build/app/outputs/flutter-apk/app-debug.apk
```

The completed debug artifact is present at the path above. A non-fatal Gradle
warning notes that `share_plus` still applies the Kotlin Gradle Plugin and may
need a future upgrade for Flutter's Built-in Kotlin transition.

---

## 9. Remaining product work (outside this completion pass)

1. **Real catalogue imagery** — implement the approved cached preview-image
   widget for rights-cleared entries. Never substitute procedural art for a real
   entry; show loading/error/retry or explicit unavailability instead.
2. **Deep-link fallback** — add browser/copy/store recovery when the external
   game handoff fails, without claiming an import succeeded.
3. **Taxonomy** — add defensive tags only from explicit source evidence and
   preserve unknown/unclassified values.
4. **In-app updater** — implement the approved GitHub Releases design, including
   patch notes, streamed progress, checksum verification, and installer handoff.
5. **Onboarding pages 2–3** — replace the documented placeholder copy when
   final product copy is available.
6. **Notifications** — the current Home action opens an honest placeholder
   sheet; a real notification integration remains future work.
7. **Rights clearance** — obtain documented content and preview redistribution
   permission before enabling any upstream catalogue records or publishing a
   public APK. Current cleared count remains zero.

---

## 10. Definition of done

- [x] `flutter analyze --no-fatal-infos`: 0 errors, 0 warnings; 110 retained info-level diagnostics.
- [x] `flutter test`: all 167 tests pass, including 19 rights-gated catalogue tests and nine golden comparisons.
- [x] Goldens reviewed against `shots/ref_*.png`; remaining differences are the documented §6 export/mock resolutions.
- [x] `flutter build apk --debug` produces a CRC-valid 195,208,931-byte APK with no unresolved catalogue JSON.
- [x] Automated interaction coverage: three-tab navigation, search/suggestions/clear, village + TH/BH selection, category chips, filter draft/reset/apply/badge, sorting, persistent favourites, Detail/back, copy/share feedback, preview zoom/reset, retry, and Open in Game fallback.
- [x] Connected-device smoke test covered branded launch, persisted onboarding, Home/Explore/Collections, and the honest empty catalogue state.
- [x] No dead buttons; missing integrations surface explicit fallbacks or placeholder copy.

## 11. Working agreements

- Reproduce the reference; when something is ambiguous, follow the HTML
  markup first, the rendered artboard second, and record the choice in code
  comments + this file.
- Keep placeholder data clearly marked (`isSample: true`) and never invent
  real ratings/creators/stats.
- Small verifiable steps; run analyze after each screen-level change; report
  files changed and what remains.
