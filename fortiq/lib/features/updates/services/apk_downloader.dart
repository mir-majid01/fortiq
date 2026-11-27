import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:fortiq/features/updates/models/update_info.dart';
import 'package:fortiq/features/updates/services/update_service.dart';
import 'package:path_provider/path_provider.dart';

typedef ApkProgressCallback = void Function(ApkDownloadProgress progress);

/// One real streamed download sample. Speed and ETA are derived from received
/// bytes and a monotonic stopwatch, never from a timer-based fake animation.
class ApkDownloadProgress {
  const ApkDownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.bytesPerSecond,
    required this.eta,
  });

  final int receivedBytes;
  final int totalBytes;
  final double bytesPerSecond;
  final Duration? eta;

  double? get fraction {
    if (totalBytes <= 0) return null;
    return (receivedBytes / totalBytes).clamp(0, 1).toDouble();
  }
}

class ApkDownloadedFile {
  const ApkDownloadedFile({
    required this.apkPath,
    required this.byteCount,
    required this.sha256,
  });

  final String apkPath;
  final int byteCount;
  final String sha256;
}

/// Streams an APK into app-private cache and exposes it only after both its
/// mandatory byte count and freshly fetched SHA-256 asset have been verified.
class ApkDownloader {
  ApkDownloader({
    Dio? dio,
    Future<Directory> Function()? cacheDirectory,
  })  : _dio = dio ?? Dio(),
        _cacheDirectory = cacheDirectory ?? getApplicationCacheDirectory {
    final adapter = _dio.httpClientAdapter;
    if (adapter is! TrustedRedirectAdapter) {
      _dio.httpClientAdapter = TrustedRedirectAdapter(adapter);
    }
  }

  static const cacheDirectoryName = 'fortiq_updates';

  final Dio _dio;
  final Future<Directory> Function() _cacheDirectory;

  String fileNameFor(UpdateInfo update) {
    final build = update.versionCode == null ? '' : '-${update.versionCode}';
    return 'fortiq-${update.versionName}$build.apk';
  }

  Future<Directory> _updateDirectory() async {
    try {
      final root = await _cacheDirectory();
      final directory = Directory('${root.path}/$cacheDirectoryName');
      await directory.create(recursive: true);
      return directory;
    } catch (error) {
      throw UpdateException(
        code: UpdateFailureCode.storage,
        message: 'Could not access app-private update storage.',
        cause: error,
      );
    }
  }

  Future<File> _apkFile(UpdateInfo update) async {
    final directory = await _updateDirectory();
    return File('${directory.path}/${fileNameFor(update)}');
  }

  /// Rehashes a deterministic cache entry against the current release
  /// checksum. A missing/corrupt entry is deleted and reported as a cache miss.
  Future<ApkDownloadedFile?> findVerifiedApk(
    UpdateInfo update, {
    CancelToken? cancelToken,
  }) async {
    _validateUrls(update);
    final file = await _apkFile(update);
    if (!await file.exists()) return null;

    final expectedDigest =
        await _fetchChecksum(update, cancelToken: cancelToken);
    if (!await _matches(file, update.apkSize, expectedDigest)) {
      await _deleteQuietly(file);
      return null;
    }
    return ApkDownloadedFile(
      apkPath: file.path,
      byteCount: update.apkSize,
      sha256: expectedDigest,
    );
  }

  Stream<ApkDownloadedFile> download(
    UpdateInfo update, {
    CancelToken? cancelToken,
    ApkProgressCallback? onProgress,
  }) async* {
    _validateUrls(update);
    final expectedDigest =
        await _fetchChecksum(update, cancelToken: cancelToken);
    final file = await _apkFile(update);
    if (await file.exists()) {
      if (await _matches(file, update.apkSize, expectedDigest)) {
        yield ApkDownloadedFile(
          apkPath: file.path,
          byteCount: update.apkSize,
          sha256: expectedDigest,
        );
        return;
      }
      await _deleteQuietly(file);
    }

    final stopwatch = Stopwatch()..start();
    var verified = false;
    void emit(int received) {
      final elapsedSeconds = stopwatch.elapsedMicroseconds / 1000000;
      final speed = elapsedSeconds > 0 ? received / elapsedSeconds : 0.0;
      final remaining = update.apkSize - received;
      final eta = remaining <= 0
          ? Duration.zero
          : speed > 0
              ? Duration(
                  milliseconds: ((remaining / speed) * 1000).round(),
                )
              : null;
      onProgress?.call(ApkDownloadProgress(
        receivedBytes: received,
        totalBytes: update.apkSize,
        bytesPerSecond: speed,
        eta: eta,
      ));
    }

    emit(0);
    try {
      await _dio.download(
        update.apkUrl,
        file.path,
        cancelToken: cancelToken,
        deleteOnError: true,
        onReceiveProgress: (received, _) => emit(received),
        options: Options(
          headers: UpdateService.requestHeaders,
          responseType: ResponseType.stream,
          followRedirects: false,
          receiveTimeout: const Duration(minutes: 10),
          sendTimeout: const Duration(seconds: 20),
        ),
      );
      emit(await file.length());
      await _verify(file, update.apkSize, expectedDigest);
      verified = true;
      yield ApkDownloadedFile(
        apkPath: file.path,
        byteCount: update.apkSize,
        sha256: expectedDigest,
      );
    } on UpdateException {
      rethrow;
    } on DioException catch (error) {
      throw _mapDioException(error);
    } catch (error) {
      throw UpdateException(
        code: UpdateFailureCode.downloadFailed,
        message: 'The update download failed. Try again.',
        cause: error,
      );
    } finally {
      stopwatch.stop();
      if (!verified) await _deleteQuietly(file);
    }
  }

  /// Keeps the current verified APK and removes only older Fortiq APK cache
  /// entries. Unrelated app-cache files are never touched.
  Future<void> cleanupOldApks({String? keepPath}) async {
    final directory = await _updateDirectory();
    if (!await directory.exists()) return;
    final pattern = RegExp(r'^fortiq-.+\.apk$');
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File ||
            !pattern.hasMatch(entity.uri.pathSegments.last)) {
          continue;
        }
        if (keepPath != null &&
            await FileSystemEntity.identical(entity.path, keepPath)) {
          continue;
        }
        await entity.delete();
      }
    } catch (error) {
      throw UpdateException(
        code: UpdateFailureCode.storage,
        message: 'Could not clean old update files.',
        cause: error,
      );
    }
  }

  Future<String> _fetchChecksum(
    UpdateInfo update, {
    CancelToken? cancelToken,
  }) async {
    validateUpdateUrl(update.checksumUrl);
    try {
      final response = await _dio.get<String>(
        update.checksumUrl,
        cancelToken: cancelToken,
        options: Options(
          headers: UpdateService.requestHeaders,
          responseType: ResponseType.plain,
          followRedirects: false,
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      return _parseChecksum(response.data);
    } on UpdateException {
      rethrow;
    } on DioException catch (error) {
      final adapterError = error.error;
      if (adapterError is UpdateException) throw adapterError;
      if (error.type == DioExceptionType.cancel) {
        throw const UpdateException(
          code: UpdateFailureCode.cancelled,
          message: 'Update download cancelled.',
        );
      }
      if (error.response?.statusCode == 404) {
        throw const UpdateException(
          code: UpdateFailureCode.checksumMissing,
          message: 'The required SHA-256 checksum asset is unavailable.',
        );
      }
      throw const UpdateException(
        code: UpdateFailureCode.network,
        message: 'Could not download the required SHA-256 checksum.',
      );
    } catch (error) {
      throw const UpdateException(
        code: UpdateFailureCode.checksumInvalid,
        message: 'The SHA-256 checksum asset is invalid.',
      );
    }
  }

  static String _parseChecksum(String? text) {
    if (text == null || text.trim().isEmpty) {
      throw const FormatException('Checksum is empty');
    }
    final lines = text.trim().split(RegExp(r'\r?\n'));
    if (lines.length != 1) {
      throw const FormatException('Checksum must contain one digest');
    }
    final match = RegExp(
      r'^([0-9a-fA-F]{64})(?:\s+\*?.+)?$',
    ).firstMatch(lines.single);
    if (match == null) {
      throw const FormatException('Checksum is not SHA-256');
    }
    return match.group(1)!.toLowerCase();
  }

  static Future<bool> _matches(
    File file,
    int expectedSize,
    String expectedDigest,
  ) async {
    try {
      if (await file.length() != expectedSize) return false;
      final digest = await file.openRead().transform(sha256).first;
      return digest.toString() == expectedDigest;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _verify(
    File file,
    int expectedSize,
    String expectedDigest,
  ) async {
    final actualSize = await file.length();
    if (actualSize != expectedSize) {
      throw const UpdateException(
        code: UpdateFailureCode.sizeMismatch,
        message: 'The APK byte count does not match the release metadata.',
      );
    }
    final digest = await file.openRead().transform(sha256).first;
    if (digest.toString() != expectedDigest) {
      throw const UpdateException(
        code: UpdateFailureCode.checksumMismatch,
        message: 'The APK SHA-256 checksum does not match. Download blocked.',
      );
    }
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Preserve the original recoverable error. A later attempt can retry.
    }
  }

  static void _validateUrls(UpdateInfo update) {
    validateUpdateUrl(update.apkUrl);
    validateUpdateUrl(update.checksumUrl);
    validateUpdateUrl(update.releaseUrl);
  }

  static UpdateException _mapDioException(DioException error) {
    final adapterError = error.error;
    if (adapterError is UpdateException) return adapterError;
    if (error.type == DioExceptionType.cancel) {
      return const UpdateException(
        code: UpdateFailureCode.cancelled,
        message: 'Update download cancelled.',
      );
    }
    if (error.response?.statusCode == 404) {
      return const UpdateException(
        code: UpdateFailureCode.downloadFailed,
        message: 'The APK asset is no longer available. Open the release page.',
      );
    }
    return const UpdateException(
      code: UpdateFailureCode.network,
      message: 'The APK download failed. Check your connection and try again.',
    );
  }
}
