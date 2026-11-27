import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/features/updates/controllers/update_controller.dart';
import 'package:fortiq/features/updates/models/update_info.dart';
import 'package:fortiq/features/updates/services/apk_downloader.dart';
import 'package:fortiq/features/updates/services/apk_installer.dart';
import 'package:fortiq/features/updates/services/update_service.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _apkUrl =
    'https://github.com/mir-majid01/fortiq/releases/download/v1.2.3/app-debug.apk';
const _checksumUrl = '$_apkUrl.sha256';
const _abcDigest =
    'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
const _defDigest =
    'cb8379ac2098aa165029e3938a51da0bcecfc008fd6795f401178647f96c5b34';

Map<String, dynamic> releaseJson({
  String tag = 'v1.2.3',
  dynamic versionCode = 4,
  bool draft = false,
  bool prerelease = false,
  bool includeApk = true,
  bool includeChecksum = true,
  String? apkUrl = _apkUrl,
  String? checksumUrl = _checksumUrl,
  dynamic apkSize = 3,
  String? releaseUrl =
      'https://github.com/mir-majid01/fortiq/releases/tag/v1.2.3',
}) {
  return {
    'tag_name': tag,
    'version_code': versionCode,
    'draft': draft,
    'prerelease': prerelease,
    'name': 'Fortiq 1.2.3',
    'published_at': '2026-11-26T10:30:00Z',
    'body': '## Improvements\n- Faster catalogue loading',
    'html_url': releaseUrl,
    'assets': [
      if (includeApk)
        {
          'name': 'app-debug.apk',
          'size': apkSize,
          'browser_download_url': apkUrl,
          'digest': 'sha256:$_abcDigest',
        },
      if (includeChecksum)
        {
          'name': 'app-debug.apk.sha256',
          'size': 82,
          'browser_download_url': checksumUrl,
        },
    ],
  };
}

PackageInfo packageInfo({String version = '1.2.2', String build = '3'}) {
  return PackageInfo(
    appName: 'Fortiq',
    packageName: 'com.example.fortiq',
    version: version,
    buildNumber: build,
  );
}

ResponseBody jsonResponse(Object body, {int statusCode = 200}) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );
}

class StubAdapter implements HttpClientAdapter {
  StubAdapter(this.respond);

  final Future<ResponseBody> Function(RequestOptions options) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

UpdateService serviceWith(StubAdapter adapter, {PackageInfo? installed}) {
  return UpdateService(
    dio: Dio()..httpClientAdapter = adapter,
    packageInfo: installed ?? packageInfo(),
  );
}

Future<void> expectUpdateFailure(
  Future<Object?> future,
  UpdateFailureCode code, {
  String? reason,
}) async {
  await expectLater(
    future,
    throwsA(
      isA<UpdateException>().having((error) => error.code, 'code', code),
    ),
    reason: reason,
  );
}

void main() {
  group('UpdateService', () {
    test('uses the stable endpoint and parses a complete valid release',
        () async {
      final adapter = StubAdapter((_) async => jsonResponse(releaseJson()));
      final service = serviceWith(adapter);

      final result = await service.checkLatest();

      expect(result.isUpdateAvailable, isTrue);
      expect(result.installedVersion, '1.2.2');
      expect(result.installedBuild, 3);
      expect(result.latest.versionName, '1.2.3');
      expect(result.latest.versionCode, 4);
      expect(result.latest.releaseName, 'Fortiq 1.2.3');
      expect(result.latest.publishedAt, DateTime.utc(2026, 11, 26, 10, 30));
      expect(result.latest.notes, contains('Faster catalogue loading'));
      expect(result.latest.apkName, 'app-debug.apk');
      expect(result.latest.apkSize, 3);
      expect(result.latest.apkUrl, _apkUrl);
      expect(result.latest.checksumUrl, _checksumUrl);
      expect(result.latest.apkSha256, _abcDigest);
      expect(
        result.latest.releaseUrl,
        'https://github.com/mir-majid01/fortiq/releases/tag/v1.2.3',
      );
      expect(adapter.requests.single.path, UpdateService.latestReleaseUrl);
      expect(adapter.requests.single.headers['Accept'],
          'application/vnd.github+json');
      expect(adapter.requests.single.headers['User-Agent'],
          'Fortiq-Android-Updater');
      expect(adapter.requests.single.headers['Authorization'], isNull);
    });

    test('derives build number from stable tag metadata when GitHub omits it',
        () async {
      final adapter = StubAdapter(
        (_) async => jsonResponse(
          releaseJson(tag: 'v1.2.3+4', versionCode: null),
        ),
      );

      final result = await serviceWith(adapter).checkLatest();

      expect(result.latest.versionName, '1.2.3+4');
      expect(result.latest.versionCode, 4);
    });

    test('rejects draft releases', () async {
      final adapter = StubAdapter(
        (_) async => jsonResponse(releaseJson(draft: true)),
      );

      await expectUpdateFailure(
        serviceWith(adapter).checkLatest(),
        UpdateFailureCode.invalidRelease,
      );
    });

    test('rejects prereleases even when GitHub marks them stable', () async {
      final adapter = StubAdapter(
        (_) async => jsonResponse(releaseJson(prerelease: true)),
      );

      await expectUpdateFailure(
        serviceWith(adapter).checkLatest(),
        UpdateFailureCode.invalidRelease,
      );
    });

    test('rejects a prerelease tag without relying on the GitHub flag',
        () async {
      final adapter = StubAdapter(
        (_) async => jsonResponse(releaseJson(tag: 'v1.2.3-beta.1')),
      );

      await expectUpdateFailure(
        serviceWith(adapter).checkLatest(),
        UpdateFailureCode.invalidRelease,
      );
    });

    test('requires the exact APK asset', () async {
      final adapter = StubAdapter(
        (_) async => jsonResponse(releaseJson(includeApk: false)),
      );

      await expectUpdateFailure(
        serviceWith(adapter).checkLatest(),
        UpdateFailureCode.invalidRelease,
      );
    });

    test('requires the exact checksum asset', () async {
      final adapter = StubAdapter(
        (_) async => jsonResponse(releaseJson(includeChecksum: false)),
      );

      await expectUpdateFailure(
        serviceWith(adapter).checkLatest(),
        UpdateFailureCode.invalidRelease,
      );
    });

    test('rejects malformed semantic version tags', () async {
      for (final tag in [
        '1.2',
        'v01.2.3',
        'v1.02.3',
        'v1.2.03',
        'release-1.2.3',
        'v1.2.3.4',
        'v1.2.3-',
      ]) {
        final adapter = StubAdapter(
          (_) async => jsonResponse(releaseJson(tag: tag)),
        );

        await expectUpdateFailure(
          serviceWith(adapter).checkLatest(),
          UpdateFailureCode.invalidRelease,
          reason: tag,
        );
      }
    });

    test('rejects missing, zero, and nonnumeric APK byte counts', () async {
      for (final size in [null, 0, -1, '3']) {
        final adapter = StubAdapter(
          (_) async => jsonResponse(releaseJson(apkSize: size)),
        );

        await expectUpdateFailure(
          serviceWith(adapter).checkLatest(),
          UpdateFailureCode.invalidRelease,
          reason: 'size=$size',
        );
      }
    });

    test('rejects non-HTTPS and untrusted URLs in every release field',
        () async {
      final invalidUrls = [
        'http://github.com/mir-majid01/fortiq/app-debug.apk',
        'https://example.com/app-debug.apk',
        'https://github.com.example.com/app-debug.apk',
        'https://evil.github.com/app-debug.apk',
        'https://github.com@evil.example/app-debug.apk',
        'https://github.com:8443/app-debug.apk',
      ];

      for (final url in invalidUrls) {
        final fields = <String, dynamic>{
          'apkUrl': url,
          'checksumUrl': url,
          'releaseUrl': url,
        };
        for (final field in fields.keys) {
          final data = releaseJson();
          final assets = data['assets'] as List<dynamic>;
          if (field == 'apkUrl') {
            (assets.first as Map<String, dynamic>)['browser_download_url'] =
                url;
          } else if (field == 'checksumUrl') {
            (assets.last as Map<String, dynamic>)['browser_download_url'] = url;
          } else {
            data['html_url'] = url;
          }
          final adapter = StubAdapter((_) async => jsonResponse(data));

          await expectUpdateFailure(
            serviceWith(adapter).checkLatest(),
            UpdateFailureCode.untrustedUrl,
            reason: '$field=$url',
          );
        }
      }
    });

    test('compares semantic components numerically rather than lexically',
        () async {
      final adapter = StubAdapter(
        (_) async => jsonResponse(releaseJson(tag: 'v1.10.0', versionCode: 1)),
      );
      final result = await serviceWith(
        adapter,
        installed: packageInfo(version: '1.9.9', build: '99'),
      ).checkLatest();

      expect(result.isUpdateAvailable, isTrue);
    });

    test('uses numeric build numbers to break equal semantic version ties',
        () async {
      final adapter = StubAdapter(
        (_) async => jsonResponse(releaseJson(versionCode: 10)),
      );
      final result = await serviceWith(
        adapter,
        installed: packageInfo(version: '1.2.3', build: '9'),
      ).checkLatest();

      expect(result.isUpdateAvailable, isTrue);
    });

    test('compares semantic versions when release build metadata is absent',
        () async {
      final adapter = StubAdapter(
        (_) async => jsonResponse(
          releaseJson(tag: 'v1.2.4', versionCode: null),
        ),
      );
      final result = await serviceWith(
        adapter,
        installed: packageInfo(version: '1.2.3', build: '999'),
      ).checkLatest();

      expect(result.isUpdateAvailable, isTrue);
      expect(result.latest.versionCode, isNull);
    });

    test('reports equal and older releases as up to date', () async {
      for (final versionCode in [4, 3]) {
        final adapter = StubAdapter(
          (_) async => jsonResponse(releaseJson(versionCode: versionCode)),
        );
        final result = await serviceWith(
          adapter,
          installed: packageInfo(version: '1.2.3', build: '4'),
        ).checkLatest();

        expect(result.isUpdateAvailable, isFalse);
      }
    });

    test('returns a recoverable error for invalid installed metadata',
        () async {
      final adapter = StubAdapter((_) async => jsonResponse(releaseJson()));

      await expectUpdateFailure(
        serviceWith(
          adapter,
          installed: packageInfo(version: 'not-a-version', build: '4'),
        ).checkLatest(),
        UpdateFailureCode.invalidRelease,
      );
      expect(adapter.requests, isEmpty);
    });

    test('maps a missing public release to a recoverable no-release error',
        () async {
      final adapter = StubAdapter(
        (_) async => jsonResponse({'message': 'Not Found'}, statusCode: 404),
      );

      await expectUpdateFailure(
        serviceWith(adapter).checkLatest(),
        UpdateFailureCode.noRelease,
      );
    });

    test('maps GitHub rate limiting and exposes the reset time', () async {
      final reset = DateTime.utc(2026, 11, 26, 12);
      final adapter = StubAdapter(
        (_) async => ResponseBody.fromString(
          '{}',
          403,
          headers: {
            'x-ratelimit-reset': ['${reset.millisecondsSinceEpoch ~/ 1000}'],
          },
        ),
      );

      await expectLater(
        serviceWith(adapter).checkLatest(),
        throwsA(
          isA<UpdateException>()
              .having(
                  (error) => error.code, 'code', UpdateFailureCode.rateLimited)
              .having((error) => error.rateLimitReset, 'reset', reset),
        ),
      );
    });

    test('maps transport failures to a recoverable network error', () async {
      final adapter = StubAdapter(
        (_) async => throw DioException(
          requestOptions: RequestOptions(path: UpdateService.latestReleaseUrl),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      await expectUpdateFailure(
        serviceWith(adapter).checkLatest(),
        UpdateFailureCode.network,
      );
    });

    test('blocks an untrusted redirect before requesting its destination',
        () async {
      final adapter = StubAdapter((options) async {
        if (options.uri.host == 'api.github.com') {
          return ResponseBody.fromString(
            '',
            302,
            headers: {
              'location': ['https://evil.example/release.json'],
            },
          );
        }
        fail('The untrusted redirect destination was requested');
      });

      await expectUpdateFailure(
        serviceWith(adapter).checkLatest(),
        UpdateFailureCode.untrustedUrl,
      );
      expect(adapter.requests, hasLength(1));
    });
  });

  group('UpdateController scheduling and handoff', () {
    late UpdateInfo update;

    setUp(() {
      update = UpdateInfo(
        versionName: '1.2.3',
        versionCode: 4,
        publishedAt: DateTime.utc(2026, 11, 26),
        releaseName: 'Fortiq 1.2.3',
        notes: 'Improvements',
        apkName: 'app-debug.apk',
        apkSize: 3,
        apkUrl: _apkUrl,
        checksumUrl: _checksumUrl,
        apkSha256: _abcDigest,
        releaseUrl: 'https://github.com/mir-majid01/fortiq/releases/tag/v1.2.3',
      );
    });

    test('auto-checks at most once per 24 hours while refresh bypasses it',
        () async {
      var now = DateTime.utc(2026, 11, 26, 8);
      DateTime? storedCheck;
      final service = FakeUpdateService((_) async => UpdateCheckResult(
            latest: update,
            installedVersion: '1.2.2',
            installedBuild: 3,
            isUpdateAvailable: true,
          ));
      final first = UpdateController(
        updateService: service,
        packageInfo: packageInfo(),
        now: () => now,
        readLastCheck: () async => storedCheck,
        writeLastCheck: (value) async => storedCheck = value,
      );

      await first.initialize();
      expect(service.calls, 1);
      expect(first.status, UpdateStatus.available);
      expect(first.lastChecked, now);
      await first.initialize();
      expect(service.calls, 1);

      now = now.add(const Duration(hours: 23));
      final throttled = UpdateController(
        updateService: service,
        packageInfo: packageInfo(),
        now: () => now,
        readLastCheck: () async => storedCheck,
        writeLastCheck: (value) async => storedCheck = value,
      );
      await throttled.initialize();
      expect(service.calls, 1);

      await throttled.refresh();
      expect(service.calls, 2);
      expect(storedCheck, now);

      now = now.add(const Duration(hours: 24));
      final due = UpdateController(
        updateService: service,
        packageInfo: packageInfo(),
        now: () => now,
        readLastCheck: () async => storedCheck,
        writeLastCheck: (value) async => storedCheck = value,
      );
      await due.initialize();
      expect(service.calls, 3);
      due.dispose();
      throttled.dispose();
      first.dispose();
    });

    test('records failed automatic checks so they are not retried on reopen',
        () async {
      var now = DateTime.utc(2026, 11, 26, 8);
      DateTime? storedCheck;
      final service = FakeUpdateService(
        (_) async => throw const UpdateException(
          code: UpdateFailureCode.network,
          message: 'Network unavailable',
        ),
      );
      UpdateController controller() => UpdateController(
            updateService: service,
            packageInfo: packageInfo(),
            now: () => now,
            readLastCheck: () async => storedCheck,
            writeLastCheck: (value) async => storedCheck = value,
          );

      final first = controller();
      await first.initialize();
      expect(first.status, UpdateStatus.error);
      expect(first.error?.code, UpdateFailureCode.network);
      expect(storedCheck, now);

      now = now.add(const Duration(hours: 23));
      final second = controller();
      await second.initialize();
      expect(service.calls, 1);
      expect(second.status, UpdateStatus.idle);
      first.dispose();
      second.dispose();
    });

    test('reuses a verified APK and cleans old cache only after handoff',
        () async {
      const downloaded = ApkDownloadedFile(
        apkPath: '/cache/fortiq-1.2.3-4.apk',
        byteCount: 3,
        sha256: _abcDigest,
      );
      final downloader = FakeDownloader(cached: downloaded);
      final installer = FakeInstaller(const InstallHandoffResult.handedOff());
      final controller = UpdateController(
        updateService: FakeUpdateService((_) async => UpdateCheckResult(
              latest: update,
              installedVersion: '1.2.2',
              installedBuild: 3,
              isUpdateAvailable: true,
            )),
        apkDownloader: downloader,
        apkInstaller: installer,
        packageInfo: packageInfo(),
        isAndroid: () => true,
        readLastCheck: () async => null,
        writeLastCheck: (_) async {},
      );

      await controller.initialize();
      await controller.downloadUpdate();
      expect(controller.status, UpdateStatus.ready);
      expect(controller.downloadedApkPath, downloaded.apkPath);
      expect(downloader.downloadCalls, 0);
      expect(downloader.cleanedPath, isNull);

      await controller.installUpdate();
      expect(controller.status, UpdateStatus.handedOff);
      expect(controller.error, isNull);
      expect(downloader.cleanedPath, downloaded.apkPath);
      controller.dispose();
    });

    test('invalidates a ready APK when release checksum metadata changes',
        () async {
      const downloaded = ApkDownloadedFile(
        apkPath: '/cache/fortiq-1.2.3-4.apk',
        byteCount: 3,
        sha256: _abcDigest,
      );
      var latest = update;
      final downloader = FakeDownloader(cached: downloaded);
      final controller = UpdateController(
        updateService: FakeUpdateService((_) async => UpdateCheckResult(
              latest: latest,
              installedVersion: '1.2.2',
              installedBuild: 3,
              isUpdateAvailable: true,
            )),
        apkDownloader: downloader,
        packageInfo: packageInfo(),
        isAndroid: () => true,
        readLastCheck: () async => null,
        writeLastCheck: (_) async {},
      );

      await controller.initialize();
      await controller.downloadUpdate();
      expect(controller.status, UpdateStatus.ready);

      latest = UpdateInfo(
        versionName: update.versionName,
        versionCode: update.versionCode,
        publishedAt: update.publishedAt,
        releaseName: update.releaseName,
        notes: update.notes,
        apkName: update.apkName,
        apkSize: update.apkSize,
        apkUrl: update.apkUrl,
        checksumUrl: '$_checksumUrl?revision=2',
        apkSha256: _defDigest,
        releaseUrl: update.releaseUrl,
      );
      await controller.refresh();

      expect(controller.status, UpdateStatus.available);
      expect(controller.downloadedApkPath, isNull);
      controller.dispose();
    });

    test('keeps a verified APK and supports retry when handoff fails',
        () async {
      const downloaded = ApkDownloadedFile(
        apkPath: '/cache/fortiq-1.2.3-4.apk',
        byteCount: 3,
        sha256: _abcDigest,
      );
      final downloader = FakeDownloader(cached: downloaded);
      final installer = FakeInstaller(
        const InstallHandoffResult(
          status: InstallHandoffStatus.failed,
          message: 'Permission denied',
        ),
      );
      final controller = UpdateController(
        updateService: FakeUpdateService((_) async => UpdateCheckResult(
              latest: update,
              installedVersion: '1.2.2',
              installedBuild: 3,
              isUpdateAvailable: true,
            )),
        apkDownloader: downloader,
        apkInstaller: installer,
        packageInfo: packageInfo(),
        isAndroid: () => true,
        readLastCheck: () async => null,
        writeLastCheck: (_) async {},
      );

      await controller.initialize();
      await controller.downloadUpdate();
      await controller.installUpdate();
      expect(controller.status, UpdateStatus.error);
      expect(controller.error?.code, UpdateFailureCode.installerFailed);
      expect(controller.downloadedApkPath, downloaded.apkPath);
      expect(downloader.cleanedPath, isNull);

      installer.result = const InstallHandoffResult.handedOff();
      await controller.retry();
      expect(controller.status, UpdateStatus.handedOff);
      expect(installer.calls, 2);
      controller.dispose();
    });

    test('never attempts an APK download on iOS', () async {
      final downloader = FakeDownloader();
      final controller = UpdateController(
        updateService: FakeUpdateService((_) async => UpdateCheckResult(
              latest: update,
              installedVersion: '1.2.2',
              installedBuild: 3,
              isUpdateAvailable: true,
            )),
        apkDownloader: downloader,
        packageInfo: packageInfo(),
        isAndroid: () => false,
        readLastCheck: () async => null,
        writeLastCheck: (_) async {},
      );

      await controller.initialize();
      await controller.downloadUpdate();
      expect(controller.status, UpdateStatus.error);
      expect(controller.error?.code, UpdateFailureCode.unsupportedPlatform);
      expect(downloader.findCalls, 0);
      expect(downloader.downloadCalls, 0);
      controller.dispose();
    });
  });
}

class FakeUpdateService extends UpdateService {
  FakeUpdateService(this.handler);

  final Future<UpdateCheckResult> Function(PackageInfo? installed) handler;
  int calls = 0;

  @override
  Future<UpdateCheckResult> checkLatest({PackageInfo? installed}) {
    calls++;
    return handler(installed);
  }
}

class FakeDownloader extends ApkDownloader {
  FakeDownloader({this.cached});

  ApkDownloadedFile? cached;
  int findCalls = 0;
  int downloadCalls = 0;
  String? cleanedPath;

  @override
  Future<ApkDownloadedFile?> findVerifiedApk(
    UpdateInfo update, {
    CancelToken? cancelToken,
  }) async {
    findCalls++;
    return cached;
  }

  @override
  Stream<ApkDownloadedFile> download(
    UpdateInfo update, {
    CancelToken? cancelToken,
    ApkProgressCallback? onProgress,
  }) {
    downloadCalls++;
    return Stream.value(cached!);
  }

  @override
  Future<void> cleanupOldApks({String? keepPath}) async {
    cleanedPath = keepPath;
  }
}

class FakeInstaller extends ApkInstaller {
  FakeInstaller(this.result);

  InstallHandoffResult result;
  int calls = 0;

  @override
  Future<InstallHandoffResult> handOff(String apkPath) async {
    calls++;
    return result;
  }
}
