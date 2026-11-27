import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:fortiq/features/updates/models/update_info.dart';
import 'package:fortiq/features/updates/services/apk_downloader.dart';
import 'package:fortiq/features/updates/services/apk_installer.dart';
import 'package:fortiq/features/updates/services/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  verifying,
  ready,
  handingOff,
  handedOff,
  error,
}

/// UI-agnostic updater state. Consumers listen with `ChangeNotifier` and use
/// the explicit refresh/download/install/cancel/retry operations.
class UpdateController extends ChangeNotifier {
  UpdateController({
    required UpdateService updateService,
    ApkDownloader? apkDownloader,
    ApkInstaller? apkInstaller,
    PackageInfo? packageInfo,
    DateTime Function()? now,
    Future<DateTime?> Function()? readLastCheck,
    Future<void> Function(DateTime value)? writeLastCheck,
    bool Function()? isAndroid,
  })  : _updateService = updateService,
        _apkDownloader = apkDownloader ?? ApkDownloader(),
        _apkInstaller = apkInstaller ?? ApkInstaller(),
        _packageInfo = packageInfo,
        _now = now ?? DateTime.now,
        _readLastCheck = readLastCheck ?? _readPersistedCheck,
        _writeLastCheck = writeLastCheck ?? _persistCheck,
        _isAndroid = isAndroid ?? (() => Platform.isAndroid) {
    _installedVersion = packageInfo?.version;
    _installedBuild = int.tryParse(packageInfo?.buildNumber ?? '');
  }

  static const autoCheckInterval = Duration(hours: 24);
  static const _lastCheckKey = 'fortiq.update.last_check.v1';

  final UpdateService _updateService;
  final ApkDownloader _apkDownloader;
  final ApkInstaller _apkInstaller;
  final DateTime Function() _now;
  final Future<DateTime?> Function() _readLastCheck;
  final Future<void> Function(DateTime value) _writeLastCheck;
  final bool Function() _isAndroid;

  PackageInfo? _packageInfo;
  Future<void>? _initialization;
  Future<UpdateCheckResult?>? _activeCheck;
  CancelToken? _downloadToken;
  UpdateCheckResult? _checkResult;
  ApkDownloadedFile? _downloaded;
  UpdateInfo? _downloadedFor;
  ApkDownloadProgress? _progress;
  UpdateException? _error;
  DateTime? _lastChecked;
  String? _installedVersion;
  int? _installedBuild;
  UpdateStatus _status = UpdateStatus.idle;
  _FailedAction _lastFailedAction = _FailedAction.check;
  bool _disposed = false;

  UpdateStatus get status => _status;
  UpdateInfo? get latestUpdate => _checkResult?.latest;
  UpdateCheckResult? get checkResult => _checkResult;
  ApkDownloadProgress? get progress => _progress;
  UpdateException? get error => _error;
  DateTime? get lastChecked => _lastChecked;
  String? get downloadedApkPath => _downloaded?.apkPath;
  String? get installedVersion => _installedVersion;
  int? get installedBuild => _installedBuild;
  bool get hasUpdate => _checkResult?.isUpdateAvailable ?? false;
  bool get supportsApk => _isAndroid();
  bool get isBusy =>
      _status == UpdateStatus.checking ||
      _status == UpdateStatus.downloading ||
      _status == UpdateStatus.verifying ||
      _status == UpdateStatus.handingOff;
  bool get canDownload => hasUpdate && supportsApk && !isBusy;
  bool get canInstall => downloadedApkPath != null && supportsApk && !isBusy;

  /// Loads persisted throttle state and performs an automatic check when due.
  Future<void> initialize() {
    if (_initialization != null) return _initialization!;
    final future = _initialize();
    _initialization = future;
    return future;
  }

  Future<void> _initialize() async {
    try {
      _packageInfo ??= await PackageInfo.fromPlatform();
      _installedVersion = _packageInfo!.version;
      _installedBuild = int.tryParse(_packageInfo!.buildNumber);
    } catch (error) {
      _setError(const UpdateException(
        code: UpdateFailureCode.invalidRelease,
        message: 'Installed app version metadata is unavailable.',
      ));
      return;
    }

    try {
      _lastChecked = await _readLastCheck();
    } catch (_) {
      // A storage failure must not prevent a network check.
    }
    if (!_disposed) await checkForUpdates(automatic: true);
  }

  /// Manual refresh always bypasses the 24-hour automatic-check throttle.
  Future<UpdateCheckResult?> refresh() => checkForUpdates();

  Future<UpdateCheckResult?> checkForUpdates({bool automatic = false}) {
    if (_disposed) return Future<UpdateCheckResult?>.value(null);
    final now = _now();
    if (automatic &&
        _lastChecked != null &&
        now.isBefore(_lastChecked!.add(autoCheckInterval))) {
      return Future<UpdateCheckResult?>.value(null);
    }
    if (_activeCheck != null) return _activeCheck!;

    late final Future<UpdateCheckResult?> future;
    future = _performCheck().whenComplete(() {
      if (identical(_activeCheck, future)) _activeCheck = null;
    });
    _activeCheck = future;
    return future;
  }

  Future<UpdateCheckResult?> _performCheck() async {
    _lastFailedAction = _FailedAction.check;
    _error = null;
    _setStatus(UpdateStatus.checking);
    try {
      final package = _packageInfo ?? await PackageInfo.fromPlatform();
      _packageInfo = package;
      final result = await _updateService.checkLatest(installed: package);
      if (_disposed) return null;

      _checkResult = result;
      _installedVersion = result.installedVersion;
      _installedBuild = result.installedBuild;
      if (result.isUpdateAvailable) {
        if (_downloaded != null &&
            !_sameRelease(_downloadedFor, result.latest)) {
          _downloaded = null;
          _downloadedFor = null;
          _progress = null;
        }
        if (_downloaded != null &&
            (_status == UpdateStatus.ready ||
                _status == UpdateStatus.handedOff)) {
          _setStatus(_status);
        } else {
          _setStatus(UpdateStatus.available);
        }
      } else {
        _downloaded = null;
        _downloadedFor = null;
        _progress = null;
        _setStatus(UpdateStatus.upToDate);
      }
      return result;
    } catch (error) {
      if (!_disposed) _setError(_asUpdateException(error));
      return null;
    } finally {
      _lastChecked = _now();
      try {
        await _writeLastCheck(_lastChecked!);
      } catch (_) {
        // The in-memory throttle still applies if persistence is unavailable.
      }
    }
  }

  Future<void> downloadUpdate() async {
    if (_disposed) return;
    final update = _checkResult?.latest;
    if (update == null || !_checkResult!.isUpdateAvailable) {
      _lastFailedAction = _FailedAction.check;
      _setError(const UpdateException(
        code: UpdateFailureCode.invalidRelease,
        message: 'Check for an update before downloading.',
      ));
      return;
    }
    if (!supportsApk) {
      _lastFailedAction = _FailedAction.download;
      _setError(const UpdateException(
        code: UpdateFailureCode.unsupportedPlatform,
        message: 'Updates are managed by the App Store on iOS.',
      ));
      return;
    }
    if (_downloadToken != null) return;

    _lastFailedAction = _FailedAction.download;
    _error = null;
    _progress = null;
    _setStatus(UpdateStatus.verifying);
    final token = CancelToken();
    _downloadToken = token;
    try {
      final cached = await _apkDownloader.findVerifiedApk(
        update,
        cancelToken: token,
      );
      if (_disposed) return;
      if (cached != null) {
        _setDownloaded(cached, update);
        _setStatus(UpdateStatus.ready);
        return;
      }

      _setStatus(UpdateStatus.downloading);
      ApkDownloadedFile? downloaded;
      await for (final file in _apkDownloader.download(
        update,
        cancelToken: token,
        onProgress: (progress) {
          if (_disposed) return;
          _progress = progress;
          if (progress.totalBytes > 0 &&
              progress.receivedBytes >= progress.totalBytes) {
            _setStatus(UpdateStatus.verifying);
          } else if (_status != UpdateStatus.downloading) {
            _setStatus(UpdateStatus.downloading);
          }
        },
      )) {
        downloaded = file;
      }
      if (_disposed) return;
      if (downloaded == null) {
        throw const UpdateException(
          code: UpdateFailureCode.downloadFailed,
          message: 'The update download did not produce a verified APK.',
        );
      }
      _setDownloaded(downloaded, update);
      _setStatus(UpdateStatus.ready);
    } catch (error) {
      if (_disposed) return;
      if (token.isCancelled ||
          (error is UpdateException && error.isCancellation)) {
        _progress = null;
        _error = null;
        _setStatus(UpdateStatus.available);
      } else {
        _setError(_asUpdateException(error));
      }
    } finally {
      if (identical(_downloadToken, token)) _downloadToken = null;
    }
  }

  void cancelDownload() {
    _downloadToken?.cancel('user cancelled');
  }

  Future<void> installUpdate() async {
    if (_disposed) return;
    final downloaded = _downloaded;
    if (downloaded == null) {
      _lastFailedAction = _FailedAction.download;
      _setError(const UpdateException(
        code: UpdateFailureCode.invalidRelease,
        message: 'Download and verify an update before opening the installer.',
      ));
      return;
    }
    if (!supportsApk) {
      _lastFailedAction = _FailedAction.install;
      _setError(const UpdateException(
        code: UpdateFailureCode.unsupportedPlatform,
        message: 'Updates are managed by the App Store on iOS.',
      ));
      return;
    }

    _lastFailedAction = _FailedAction.install;
    _error = null;
    _setStatus(UpdateStatus.handingOff);
    try {
      final result = await _apkInstaller.handOff(downloaded.apkPath);
      if (_disposed) return;
      if (result.status == InstallHandoffStatus.handedOff) {
        _setStatus(UpdateStatus.handedOff);
        try {
          await _apkDownloader.cleanupOldApks(keepPath: downloaded.apkPath);
        } catch (_) {
          // Cache cleanup is best-effort and must not change the handoff result.
        }
      } else {
        _setError(UpdateException(
          code: UpdateFailureCode.installerFailed,
          message: result.message,
        ));
      }
    } catch (error) {
      if (!_disposed) _setError(_asUpdateException(error));
    }
  }

  Future<void> retry() async {
    if (_lastFailedAction == _FailedAction.install && _downloaded != null) {
      await installUpdate();
    } else if (_lastFailedAction == _FailedAction.download && hasUpdate) {
      await downloadUpdate();
    } else {
      await refresh();
    }
  }

  void _setDownloaded(ApkDownloadedFile downloaded, UpdateInfo update) {
    _downloaded = downloaded;
    _downloadedFor = update;
  }

  static bool _sameRelease(UpdateInfo? previous, UpdateInfo next) =>
      previous != null &&
      previous.versionName == next.versionName &&
      previous.versionCode == next.versionCode &&
      previous.apkUrl == next.apkUrl &&
      previous.apkSize == next.apkSize &&
      previous.checksumUrl == next.checksumUrl &&
      previous.apkSha256 == next.apkSha256;

  static UpdateException _asUpdateException(Object error) {
    if (error is UpdateException) return error;
    return UpdateException(
      code: UpdateFailureCode.unknown,
      message: 'Something went wrong while updating. Try again.',
      cause: error,
    );
  }

  void _setStatus(UpdateStatus status) {
    if (_disposed) return;
    _status = status;
    notifyListeners();
  }

  void _setError(UpdateException error) {
    if (_disposed) return;
    _error = error;
    _status = UpdateStatus.error;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _downloadToken?.cancel('controller disposed');
    super.dispose();
  }
}

enum _FailedAction { check, download, install }

Future<DateTime?> _readPersistedCheck() async {
  final preferences = await SharedPreferences.getInstance();
  final milliseconds = preferences.getInt(UpdateController._lastCheckKey);
  if (milliseconds == null) return null;
  return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
}

Future<void> _persistCheck(DateTime value) async {
  final preferences = await SharedPreferences.getInstance();
  await preferences.setInt(
    UpdateController._lastCheckKey,
    value.millisecondsSinceEpoch,
  );
}
