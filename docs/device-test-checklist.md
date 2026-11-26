# Fortiq Device Test Checklist

Use the latest private test release from `mir-majid01/fortiq-test-builds`. Record device model, Android version, build tag, steps, expected/actual result, and a screenshot/video for every failure.

## Native launch and launcher

- Cold launch shows the Fortiq gold shield on `#0B0D10`.
- No Flutter logo, white flash, or blank frame appears.
- Android 12+ mask/scale is correct and the crest does not jump at the Flutter handoff.
- Launcher label is `Fortiq`.
- Launcher icon is the Fortiq shield, not Flutter.
- Force-stop/relaunch repeats the same branded sequence.

## Onboarding persistence

- Fresh install/first launch shows onboarding after the splash.
- Leaving onboarding incomplete and force-stopping does not mark it complete.
- Finish or Skip opens Home only after completion is saved.
- Force-stop/relaunch after completion opens Home without onboarding.
- Process recreation/normal restart preserves completion.

## Navigation and existing features

- Production navigation contains Home, Explore, and Collections only.
- No Profile item/screen and no fabricated Community creators remain.
- Search, suggestions, clear, quick chips, filters, sorting, and counts work.
- Base card opens Detail; Back returns correctly.
- Favourite/unfavourite survives force-stop/relaunch.
- Collections shows saved real bases, a useful empty state, and stale-ID handling.
- Copy/share provide one honest feedback message.
- Open in Game passes the real link unchanged or shows a clear fallback.
- Preview zoom/reset works for authorized images.

## Real catalogue and rights

- Every displayed production base is rights-cleared and marked with source attribution.
- No sample/fake base appears as real production data.
- No fabricated ratings, copies, verification, creators, or defensive tags appear.
- Real previews show loading/error/retry states; no procedural substitute is used for real entries.
- Unknown classifications remain unclassified.
- Builder Base entries are not misclassified as Home Village.

## Updater

- Home Updates icon opens the update page.
- Current/latest version, date, size, checksum, and patch notes are visible.
- Download progress is real and cancellable.
- Checksum mismatch blocks installation.
- Android package installer handoff works; the app does not claim import/install completion prematurely.
- Offline/rate-limit/no-release/install errors have recovery actions.

## Visual/responsive regression

- Home, Explore, Filters, Detail, and bottom nav retain the approved dark/gold design.
- Small phone, landscape, large text, and safe areas do not clip or hide critical actions.
