# Fortiq GitHub Releases Updater Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans or superpowers:subagent-driven-development to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an Android-first in-app updater that reads public GitHub Releases, shows detailed version/patch-note/asset information, downloads with real progress, verifies SHA-256, and hands the APK to Android's installer.

**Architecture:** Keep the existing Flutter architecture. Add an injectable `UpdateService` for release metadata/version comparison, an `ApkDownloader` for streamed download/checksum verification, a `ChangeNotifier` controller for UI state, and a dedicated `UpdateScreen`. Home's removed profile action is replaced by an Updates icon.

**Tech Stack:** Flutter 3.50.1, `dio`, `package_info_plus`, `path_provider`, `crypto`, `install_plugin`, `flutter_markdown`, existing `url_launcher`.

**Spec:** `C:\Users\HP\Desktop\Fortiq\docs\superpowers\specs\2026-11-26-github-releases-updater-design.md`

## Global Constraints

- Stable public GitHub Releases only; no tokens embedded in the app.
- Enforce HTTPS and GitHub host allowlists.
- Require APK byte count and SHA-256 match before install.
- Never claim the update installed merely because the system installer opened.
- No procedural/fake data or rights-uncleared content in public release APKs.
- Preserve approved dark/gold UI and existing navigation style.
- iOS shows App Store guidance and never sideloads.
- Run analyzer/full tests/build exactly; no filtered verification output.

---

### Task 1: Release metadata and version comparison

**Files:**
- Create: `fortiq/lib/features/updates/models/update_info.dart`
- Create: `fortiq/lib/features/updates/services/update_service.dart`
- Create: `fortiq/test/update_service_test.dart`
- Modify: `fortiq/pubspec.yaml`

**Interfaces:**
- Consumes: `PackageInfo`, GitHub `releases/latest` JSON, injectable `Dio`.
- Produces: `UpdateInfo`, `UpdateCheckResult`, `UpdateService.checkLatest()`.

- [ ] Add failing tests for valid release parsing, draft/prerelease rejection, APK/checksum asset selection, semantic/build comparison, invalid tags, missing assets, non-HTTPS URLs, and untrusted hosts.
- [ ] Add `dio` and `package_info_plus`.
- [ ] Implement immutable `UpdateInfo` with versionName, versionCode, publishedAt, releaseName, notes, APK name/size/URL/SHA-256, and release URL.
- [ ] Implement `UpdateService` using `https://api.github.com/repos/mir-majid01/fortiq/releases/latest`, `Accept: application/vnd.github+json`, and `User-Agent: Fortiq-Android-Updater`.
- [ ] Compare installed version/build numerically; invalid metadata returns a recoverable error.

### Task 2: Streamed download, checksum, and installer handoff

**Files:**
- Create: `fortiq/lib/features/updates/services/apk_downloader.dart`
- Create: `fortiq/lib/features/updates/services/apk_installer.dart`
- Create: `fortiq/test/apk_downloader_test.dart`
- Modify: `fortiq/pubspec.yaml`
- Modify: `fortiq/android/app/src/main/AndroidManifest.xml`

**Interfaces:**
- Consumes: `UpdateInfo`, app-private directory, `Dio`, `crypto`, `InstallPlugin`.
- Produces: progress stream, verified APK path, installer handoff result.

- [ ] Add failing tests for streamed progress, cancellation/partial-file deletion, byte-count mismatch, SHA-256 mismatch, valid checksum, HTTPS/host validation, and installer failure.
- [ ] Add `path_provider`, `install_plugin`, and direct `crypto`.
- [ ] Add `android.permission.REQUEST_INSTALL_PACKAGES`.
- [ ] Implement download to a deterministic version/build filename with `deleteOnError: true`, progress callback, cancel token, and no external-storage permission.
- [ ] Download/parse the mandatory `.sha256` asset and block install on missing/mismatched digest.
- [ ] Implement installer handoff that reports only “installer opened” or a recoverable failure.

### Task 3: Update controller and detailed update page

**Files:**
- Create: `fortiq/lib/features/updates/controllers/update_controller.dart`
- Create: `fortiq/lib/features/updates/update_screen.dart`
- Create: `fortiq/lib/features/updates/widgets/update_status_card.dart`
- Create: `fortiq/test/update_screen_test.dart`
- Modify: `fortiq/lib/features/home/home_screen.dart`
- Modify: `fortiq/lib/core/icons/fortiq_icons.dart` only if an existing update icon is insufficient

**Interfaces:**
- Consumes: `UpdateService`, `ApkDownloader`, `ApkInstaller`, installed `PackageInfo`.
- Produces: checking/up-to-date/available/downloading/verifying/ready/installing/error states and Home navigation.

- [ ] Add failing widget tests for every state, large text/narrow phone, real progress formatting, cancel/retry/open-release/copy-link actions, and Home Updates icon navigation/badge.
- [ ] Add `flutter_markdown` for release notes.
- [ ] Implement `UpdateController` with automatic once-per-24-hour check, manual refresh, cancellation, retry, cached verified APK reuse, and old-cache cleanup.
- [ ] Build the approved dark/gold update page: current/latest version, release date, size, checksum status, patch notes, progress percentage/MB/speed/ETA, and primary/secondary actions.
- [ ] Replace the removed Home profile affordance with an Updates icon and badge; no bottom-navigation item is added.
- [ ] On iOS, replace download/install actions with App Store guidance.

### Task 4: Release workflow and live verification

**Files:**
- Create: `.github/workflows/release.yml` at the repository root
- Modify: root `README.md`
- Modify: `HANDOVER.md`

- [ ] Add a tagged `v*` workflow that runs analyzer/tests, builds the debug APK, calculates SHA-256, and uploads `app-debug.apk` plus `app-debug.apk.sha256` and notes.
- [ ] Add a rights-review gate that refuses public release if unresolved catalogue content is present.
- [ ] Test release JSON/assets against updater expectations.
- [ ] Build/install a private test APK and verify update-page states with mocked/service tests.
- [ ] When a rights-cleared public release exists, device-test check → download → checksum → installer handoff.
- [ ] Record live GitHub/device limitations honestly if no public rights-cleared release is available.

## Execution Order

Run after maintenance Tasks 3–6 to avoid shared `pubspec.yaml`, Home header, navigation, and catalogue conflicts. Task 1 and Task 2 may be implemented as one focused unit if dependency changes are handled together.
