import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/features/updates/models/update_info.dart';
import 'package:fortiq/features/updates/services/apk_downloader.dart';
import 'package:fortiq/features/updates/services/apk_installer.dart';

const _apkUrl =
    'https://github.com/mir-majid01/fortiq/releases/download/v1.2.3/app-debug.apk';
const _checksumUrl = '$_apkUrl.sha256';
const _abcDigest =
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
const _defDigest =
    'cb8379ac2098aa165029e3938a51da0bcecfc008fd6795f401178647f96c5b34';

UpdateInfo update({
  String? apkUrl,
  String? checksumUrl,
  int apkSize = 3,
}) {
  return UpdateInfo(
    versionName: '1.2.3',
    versionCode: 4,
    publishedAt: DateTime.utc(2026, 11, 26),
    releaseName: 'Fortiq 1.2.3',
    notes: 'Improvements',
    apkName: 'app-debug.apk',
    apkSize: apkSize,
    apkUrl: apkUrl ?? _apkUrl,
    checksumUrl: checksumUrl ?? _checksumUrl,
    apkSha256: _abcDigest,
    releaseUrl: 'https://github.com/mir-majid01/fortiq/releases/tag/v1.2.3',
  );
}

class DownloadAdapter implements HttpClientAdapter {
  DownloadAdapter({
    this.checksumText = '$_abcDigest  app-debug.apk\n',
    this.bytes = const [1, 2],
    this.body = 'abc',
    this.omitContentLength = false,
    this.chunkDelay = Duration.zero,
    this.waitForCancel = false,
    this.failAfterFirstChunk = false,
  });

  String checksumText;
  List<int> bytes;
  String body;
  bool omitContentLength;
  Duration chunkDelay;
  bool waitForCancel;
  bool failAfterFirstChunk;
  final List<RequestOptions> requests = [];
  final Completer<void> firstApkChunk = Completer<void>();

  int get apkRequests =>
      requests.where((request) => request.uri.toString() == _apkUrl).length;

  int get checksumRequests => requests
      .where((request) => request.uri.toString() == _checksumUrl)
      .length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.uri.toString() == _checksumUrl) {
      return ResponseBody.fromString(
        checksumText,
        200,
        headers: {
          Headers.contentTypeHeader: ['text/plain'],
        },
      );
    }
    if (options.uri.toString() != _apkUrl) {
      throw StateError('Unexpected URL ${options.uri}');
    }

    final data = Uint8List.fromList(utf8.encode(body));
    var emitted = false;
    Stream<Uint8List> stream() async* {
      var offset = 0;
      for (final size in bytes) {
        final end = (offset + size).clamp(0, data.length);
        if (end > offset) {
          if (!emitted) {
            emitted = true;
            if (!firstApkChunk.isCompleted) {
              firstApkChunk.complete();
            }
          }
          yield data.sublist(offset, end);
          offset = end;
          if (chunkDelay > Duration.zero) {
            await Future<void>.delayed(chunkDelay);
          }
        }
      }
      if (offset < data.length) {
        if (!emitted && !firstApkChunk.isCompleted) {
          firstApkChunk.complete();
        }
        yield data.sublist(offset);
      }
      if (waitForCancel) {
        await cancelFuture;
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
        );
      }
      if (failAfterFirstChunk) {
        throw DioException(
          requestOptions: options,
          type: DioExceptionType.receiveTimeout,
          error: const SocketException('connection lost'),
        );
      }
    }

    return ResponseBody(
      stream(),
      200,
      headers: {
        if (!omitContentLength) Headers.contentLengthHeader: ['${data.length}'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Matcher downloadFailure(UpdateFailureCode code) {
  return throwsA(
    isA<UpdateException>().having((error) => error.code, 'code', code),
  );
}

void main() {
  late Directory cacheRoot;
  late DownloadAdapter adapter;
  late ApkDownloader downloader;

  setUp(() async {
    cacheRoot = await Directory.systemTemp.createTemp('fortiq_updater_test_');
    adapter = DownloadAdapter();
    downloader = ApkDownloader(
      dio: Dio()..httpClientAdapter = adapter,
      cacheDirectory: () async => cacheRoot,
    );
  });

  tearDown(() async {
    if (await cacheRoot.exists()) {
      await cacheRoot.delete(recursive: true);
    }
  });

  File expectedFile() {
    return File(
      '${cacheRoot.path}/fortiq_updates/${downloader.fileNameFor(update())}',
    );
  }

  test('streams real byte progress with speed and ETA', () async {
    adapter.chunkDelay = const Duration(milliseconds: 30);
    final progress = <ApkDownloadProgress>[];

    final result =
        await downloader.download(update(), onProgress: progress.add).first;

    expect(progress.first.receivedBytes, 0);
    expect(progress.first.totalBytes, 3);
    expect(progress.any((event) => event.receivedBytes == 1), isTrue);
    final partial = progress.firstWhere((event) => event.receivedBytes == 1);
    expect(partial.fraction, closeTo(1 / 3, 0.001));
    expect(partial.bytesPerSecond, greaterThan(0));
    expect(partial.eta, isNotNull);
    expect(partial.eta!, greaterThan(Duration.zero));
    expect(progress.last.receivedBytes, 3);
    expect(progress.last.fraction, 1);
    expect(result.byteCount, 3);
    expect(result.sha256, _abcDigest);
  });

  test('writes a deterministic app-private filename and exact bytes', () async {
    final result = await downloader.download(update()).first;
    final file = File(result.apkPath);

    expect(file.path, expectedFile().path);
    expect(file.path, endsWith('fortiq-1.2.3-4.apk'));
    expect(await file.readAsString(), 'abc');
    expect(adapter.checksumRequests, 1);
    expect(adapter.apkRequests, 1);
  });

  test('uses mandatory release size when Content-Length is absent', () async {
    adapter.omitContentLength = true;
    final progress = <ApkDownloadProgress>[];

    await downloader.download(update(), onProgress: progress.add).first;

    expect(progress.every((event) => event.totalBytes == 3), isTrue);
    expect(progress.last.fraction, 1);
  });

  test('re-downloads the checksum asset instead of trusting advertised digest',
      () async {
    adapter.checksumText = '$_defDigest\n';

    await expectLater(
      downloader.download(update()).first,
      downloadFailure(UpdateFailureCode.checksumMismatch),
    );
    expect(adapter.checksumRequests, 1);
  });

  test('rejects an empty or malformed checksum asset', () async {
    for (final text in ['', 'not-a-sha256', '$_abcDigest\nextra']) {
      adapter.checksumText = text;
      await expectLater(
        downloader.download(update()).first,
        downloadFailure(UpdateFailureCode.checksumInvalid),
      );
    }
    expect(adapter.apkRequests, 0);
  });

  test('deletes the APK when its byte count differs from release metadata',
      () async {
    await expectLater(
      downloader.download(update(apkSize: 4)).first,
      downloadFailure(UpdateFailureCode.sizeMismatch),
    );

    expect(await expectedFile().exists(), isFalse);
  });

  test('deletes the APK when SHA-256 does not match', () async {
    adapter.checksumText = '$_defDigest  app-debug.apk\n';

    await expectLater(
      downloader.download(update()).first,
      downloadFailure(UpdateFailureCode.checksumMismatch),
    );
    expect(await expectedFile().exists(), isFalse);
  });

  test('deletes partial bytes after a transport failure', () async {
    adapter.failAfterFirstChunk = true;

    await expectLater(
      downloader.download(update()).first,
      downloadFailure(UpdateFailureCode.network),
    );
    expect(await expectedFile().exists(), isFalse);
  });

  test('cancellation stops the stream and deletes partial bytes', () async {
    adapter.waitForCancel = true;
    final token = CancelToken();
    final done = expectLater(
      downloader.download(update(), cancelToken: token).first,
      downloadFailure(UpdateFailureCode.cancelled),
    );

    await adapter.firstApkChunk.future;
    token.cancel('user cancelled');
    await done;

    expect(await expectedFile().exists(), isFalse);
  });

  test('rejects non-HTTPS and untrusted URLs before any request', () async {
    final invalidUrls = [
      'http://github.com/mir-majid01/fortiq/app-debug.apk',
      'https://evil.example/app-debug.apk',
      'https://github.com.evil.example/app-debug.apk',
      'https://evil.github.com/app-debug.apk',
      'https://github.com@evil.example/app-debug.apk',
    ];
    for (final url in invalidUrls) {
      await expectLater(
        downloader.download(update(apkUrl: url)).first,
        downloadFailure(UpdateFailureCode.untrustedUrl),
      );
      await expectLater(
        downloader.download(update(checksumUrl: url)).first,
        downloadFailure(UpdateFailureCode.untrustedUrl),
      );
    }
    expect(adapter.requests, isEmpty);
  });

  test('reuses a cached APK only after fresh checksum and byte verification',
      () async {
    final file = expectedFile();
    await file.parent.create(recursive: true);
    await file.writeAsString('abc');

    final cached = await downloader.findVerifiedApk(update());

    expect(cached, isNotNull);
    expect(cached!.apkPath, file.path);
    expect(cached.sha256, _abcDigest);
    expect(adapter.checksumRequests, 1);
    expect(adapter.apkRequests, 0);
  });

  test('deletes a corrupt cached APK instead of reusing it', () async {
    final file = expectedFile();
    await file.parent.create(recursive: true);
    await file.writeAsString('def');

    final cached = await downloader.findVerifiedApk(update());

    expect(cached, isNull);
    expect(await file.exists(), isFalse);
    expect(adapter.apkRequests, 0);
  });

  test('cleans old Fortiq APKs while keeping current and unrelated files',
      () async {
    final directory = Directory('${cacheRoot.path}/fortiq_updates');
    await directory.create(recursive: true);
    final current = File('${directory.path}/fortiq-1.2.3-4.apk');
    final old = File('${directory.path}/fortiq-1.2.2-3.apk');
    final unrelated = File('${directory.path}/catalogue.json');
    await current.writeAsString('current');
    await old.writeAsString('old');
    await unrelated.writeAsString('{}');

    await downloader.cleanupOldApks(keepPath: current.path);

    expect(await current.exists(), isTrue);
    expect(await old.exists(), isFalse);
    expect(await unrelated.exists(), isTrue);
  });

  mainInstallerTests();
}

void mainInstallerTests() {
  late Directory tempDirectory;
  late File apk;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('fortiq_installer_');
    apk = File('${tempDirectory.path}/app-debug.apk');
    await apk.writeAsBytes([1, 2, 3]);
  });

  tearDown(() async {
    await tempDirectory.delete(recursive: true);
  });

  test('maps plugin acceptance only to installer handoff', () async {
    final installer = ApkInstaller(
      isAndroid: () => true,
      install: (_) async =>
          {'isSuccess': true, 'errorMessage': 'Install Success'},
    );

    final result = await installer.handOff(apk.path);

    expect(result.status, InstallHandoffStatus.handedOff);
    expect(result.message, contains('installer'));
  });

  test('maps plugin refusal to a recoverable failed handoff', () async {
    final installer = ApkInstaller(
      isAndroid: () => true,
      install: (_) async => {'isSuccess': false, 'errorMessage': 'Denied'},
    );

    final result = await installer.handOff(apk.path);

    expect(result.status, InstallHandoffStatus.failed);
    expect(result.message, 'Denied');
  });

  test('maps malformed plugin responses and exceptions to failure', () async {
    final malformed = ApkInstaller(
      isAndroid: () => true,
      install: (_) async => null,
    );
    final throwing = ApkInstaller(
      isAndroid: () => true,
      install: (_) async => throw PlatformException(code: 'unavailable'),
    );

    expect((await malformed.handOff(apk.path)).status,
        InstallHandoffStatus.failed);
    expect(
        (await throwing.handOff(apk.path)).status, InstallHandoffStatus.failed);
  });

  test('fails without invoking the plugin when the APK is missing', () async {
    var invoked = false;
    final installer = ApkInstaller(
      isAndroid: () => true,
      install: (_) async {
        invoked = true;
        return {'isSuccess': true};
      },
    );

    final result = await installer.handOff('${tempDirectory.path}/missing.apk');

    expect(result.status, InstallHandoffStatus.failed);
    expect(invoked, isFalse);
  });

  test('never sideloads on non-Android platforms', () async {
    var invoked = false;
    final installer = ApkInstaller(
      isAndroid: () => false,
      install: (_) async {
        invoked = true;
        return {'isSuccess': true};
      },
    );

    final result = await installer.handOff(apk.path);

    expect(result.status, InstallHandoffStatus.failed);
    expect(result.message, contains('App Store'));
    expect(invoked, isFalse);
  });
}
