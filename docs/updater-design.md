# Fortiq GitHub Releases Updater Design

**Date:** 2026-11-26  
**Status:** Approved in chat; written spec for review  
**Platform:** Android-first; iOS informational only

## Goal

Let users discover, inspect, download, verify, and install the latest public Fortiq APK from GitHub Releases without leaving the app for release details. The app must never claim that Clash of Clans imported a base, and the updater must never distribute rights-uncleared catalogue content.

## Non-goals

- Silent or forced installation.
- A custom update backend, account system, or analytics service.
- Beta/prerelease channels.
- iOS self-installation; iOS users are directed to the App Store when one exists.
- Publishing any APK that contains unresolved third-party catalogue content.

## Chosen approach

Use the public GitHub Releases API as the update source, `dio` for streamed downloads, `package_info_plus` for installed version/build metadata, `path_provider` for app-private storage, `crypto` for SHA-256 verification, and a native Android `MethodChannel` with `FileProvider` for package-installer handoff.

Alternatives rejected:

1. **Custom backend/Firebase Remote Config:** adds infrastructure, credentials, and operational cost without a current requirement.
2. **Hardcoded version JSON in the repository:** requires a second app release to announce every update and provides poorer release metadata.
3. **Browser-only download:** removes the requested in-app progress/detail experience.

## Entry point and navigation

- Replace the removed Home header profile/avatar action with an Updates icon using the existing icon style and 44×44 target.
- When a newer stable release is known, show a small gold badge/dot on the icon.
- Tapping opens `UpdateScreen` through the existing `Navigator` pattern used by Detail and Filters.
- No bottom-navigation item is added; production navigation remains Home / Explore / Collections.

## Update source and metadata

Endpoint:

```text
https://api.github.com/repos/mir-majid01/fortiq/releases/latest
```

Request headers:

```dart
{
  'Accept': 'application/vnd.github+json',
  'User-Agent': 'Fortiq-Android-Updater',
}
```

`UpdateInfo` contains:

- `versionName` from the release tag (`v1.2.3` → `1.2.3`).
- `versionCode` from release metadata when present; otherwise compare semantic version only.
- `publishedAt`.
- `releaseName`.
- Markdown release notes/body.
- APK asset name, byte size, browser download URL, and SHA-256.
- Release page URL.

The latest stable release is used; drafts/prereleases are ignored. The APK asset must be named `app-debug.apk` for this release channel. A matching `.sha256` asset is mandatory.

## Version comparison

- Parse installed `PackageInfo.version` and `buildNumber`.
- Compare numeric semantic-version components; build number breaks ties when present.
- Invalid/missing release versions produce a recoverable “Release metadata is invalid” state.
- Same/older versions produce “You’re up to date.”
- Checks run automatically at most once per 24 hours and on manual refresh; failed checks do not spam the user.

## Update page UX

The page uses the existing dark/gold theme and card/typography system:

1. **Header:** “App updates” and back action.
2. **Current version card:** installed version/build and last checked time.
3. **Latest release card:** version, release date, APK size, checksum status, release page link.
4. **Patch notes card:** rendered Markdown/plain text with readable headings/bullets.
5. **Status area:**
   - Checking.
   - Up to date.
   - Update available.
   - Downloading: animated determinate progress, percentage, downloaded/total MB, speed, ETA.
   - Verifying checksum.
   - Ready to install.
   - Installing/handoff.
   - Error with Retry/Open Release/Copy Link actions.
6. **Primary action:** Download update → Verify → Install.
7. **Secondary actions:** Cancel download, Retry, Open release in browser, Copy link.

Download progress is a real streamed value, not a timed fake animation. If content length is missing, show an indeterminate animation plus downloaded MB.

## Download and verification flow

1. Validate release metadata and required APK/checksum assets.
2. Validate all URLs are HTTPS and belong to `github.com`, `api.github.com`, or `objects.githubusercontent.com`.
3. Download to app-private cache with a deterministic filename containing version and build.
4. Delete partial files on cancellation/error.
5. Re-download the small `.sha256` asset over HTTPS and parse the digest.
6. Verify downloaded byte count and SHA-256 before enabling Install.
7. Keep the verified APK for retry; clean older cached APKs after successful handoff.

A missing/mismatched checksum blocks installation. The UI explains why and offers release-page/browser actions.

## Android install handoff

Add `android.permission.REQUEST_INSTALL_PACKAGES`. On Android 8+, the user may need to grant “Install unknown apps” for Fortiq. A native `fortiq/apk_installer` method channel exposes the verified cache file through a non-exported `FileProvider` and opens `ACTION_VIEW` with `application/vnd.android.package-archive`. Fortiq reports only that the installer was handed off; it does not claim the update finished. If the result is failure/cancel, show a recovery action.

No storage permission is requested because the APK is written to app-private storage.

## iOS behavior

The update page remains available and shows installed version/release information. Download/install actions are replaced with “Updates are managed by the App Store.” No App Store URL is shown until a real listing exists.

## Release workflow

A tagged `v*` release workflow will:

1. Run analyzer and full tests.
2. Build the debug APK.
3. Calculate SHA-256.
4. Publish `app-debug.apk`, `app-debug.apk.sha256`, and release notes to the matching public GitHub Release.
5. Refuse publication if rights review has not passed.

Release publication remains a human-approved action in this repository.

## Error handling

- Offline/network timeout: retain cached metadata, show Retry.
- GitHub 403 rate limit: show reset time when available and browser fallback.
- 404/no release: show “No public release is available yet.”
- Invalid metadata/asset: block download with a clear explanation.
- Insufficient storage/download failure: delete partial file and offer Retry.
- Checksum mismatch: delete file and block install.
- Installer unavailable/permission denied: explain settings path and offer Retry/Open Release.

## Security and privacy

- No authentication token is embedded in the app.
- Release API is public and read-only.
- HTTPS and host allowlists are enforced before every network request.
- SHA-256 is mandatory; release assets are never loaded from arbitrary hosts.
- Update checks send only standard GitHub request metadata; no user identifiers are added.

## Testing

### Service/unit tests

- Parse valid release JSON and select APK/checksum assets.
- Ignore draft/prerelease releases.
- Compare older/equal/newer semantic versions and build numbers.
- Reject invalid tags, missing APK, missing checksum, non-HTTPS, and untrusted hosts.
- Stream progress/cancel/delete partial file using a fake transport.
- Verify byte count and SHA-256; reject mismatch.

### Widget tests

- Checking, up-to-date, available, downloading, verifying, ready, installing, and error states.
- Large text/narrow phone does not clip actions or patch notes.
- Progress percentage/MB/speed/ETA formatting.
- Cancel/Retry/Open Release/Copy Link actions.
- Home Updates icon opens the page and badge reflects available state.

### Platform/release tests

- Android manifest contains `REQUEST_INSTALL_PACKAGES`.
- Release workflow artifact names/checksum match updater expectations.
- Device test: download a small test APK, verify progress, checksum, and system-installer handoff.
- iOS test: no install action and correct App Store explanation.

## Acceptance criteria

- [x] User can open a dedicated updates page from Home.
- [x] Current and latest versions, date, size, checksum, and patch notes are shown.
- [x] Download progress is real, animated, cancellable, and restartable.
- [x] APK is installed only after byte-count and SHA-256 verification.
- [x] Errors have clear recovery actions.
- [x] No update is reported as installed merely because the installer opened.
- [ ] Public GitHub Release assets are fetchable without authentication.
- [x] iOS never attempts sideloading.
- [x] No rights-uncleared APK is published.
- [ ] Analyzer/tests/build pass and device handoff is verified when a device is connected.
