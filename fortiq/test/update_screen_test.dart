import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/app/theme/app_theme.dart';
import 'package:fortiq/features/updates/controllers/update_controller.dart';
import 'package:fortiq/features/updates/models/update_info.dart';
import 'package:fortiq/features/updates/services/apk_downloader.dart';
import 'package:fortiq/features/updates/services/apk_installer.dart';
import 'package:fortiq/features/updates/services/update_service.dart';
import 'package:fortiq/features/updates/update_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';

const _update = UpdateInfo(
  versionName: '1.2.3',
  versionCode: 4,
  publishedAt: null,
  releaseName: 'Fortiq 1.2.3',
  notes: '## Improvements\n- Faster catalogue loading',
  apkName: 'app-debug.apk',
  apkSize: 5 * 1024 * 1024,
  apkUrl:
      'https://github.com/mir-majid01/fortiq/releases/download/v1.2.3/app-debug.apk',
  checksumUrl:
      'https://github.com/mir-majid01/fortiq/releases/download/v1.2.3/app-debug.apk.sha256',
  apkSha256: 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
  releaseUrl: 'https://github.com/mir-majid01/fortiq/releases/tag/v1.2.3',
);

final _installed = PackageInfo(
  appName: 'Fortiq',
  packageName: 'com.fortiq.fortiq',
  version: '1.2.2',
  buildNumber: '3',
);

void main() {
  testWidgets('update page shows release details and download action',
      (tester) async {
    final controller = _controller(_FakeUpdateService(available: true));
    await controller.initialize();
    await _pumpScreen(tester, controller);

    expect(find.text('Update available'), findsOneWidget);
    await _reveal(tester, 'Download update');
    expect(find.text('Download update'), findsOneWidget);
    expect(find.text('Fortiq 1.2.3'), findsWidgets);
    expect(find.text('5.0 MB'), findsOneWidget);
    expect(find.text('Improvements'), findsOneWidget);
    expect(find.text('Faster catalogue loading'), findsOneWidget);
  });

  testWidgets('update page shows real streamed progress and ready state',
      (tester) async {
    final downloader = _FakeApkDownloader();
    final controller = _controller(
      _FakeUpdateService(available: true),
      downloader: downloader,
    );
    await controller.initialize();
    await _pumpScreen(tester, controller);

    final download = controller.downloadUpdate();
    await tester.pump();
    expect(find.text('Downloading update'), findsOneWidget);
    expect(find.textContaining('2.5 MB / 5.0 MB'), findsOneWidget);

    downloader.complete();
    await download;
    await tester.pump();
    expect(find.text('Ready to install'), findsOneWidget);
    await _reveal(tester, 'Install update');
    expect(find.text('Install update'), findsOneWidget);
  });

  testWidgets('update page reports up to date and recoverable errors',
      (tester) async {
    final current = _controller(_FakeUpdateService(available: false));
    await current.initialize();
    await _pumpScreen(tester, current);
    expect(find.text('You’re up to date'), findsOneWidget);

    final failed = _controller(
      _FakeUpdateService(
          available: true,
          error: const UpdateException(
            code: UpdateFailureCode.network,
            message: 'Could not reach GitHub.',
          )),
    );
    await failed.initialize();
    await _pumpScreen(tester, failed);
    expect(find.text('Update needs attention'), findsOneWidget);
    expect(find.text('Could not reach GitHub.'), findsOneWidget);
    await _reveal(tester, 'Retry');
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('installer handoff never claims installation completed',
      (tester) async {
    final downloader = _FakeApkDownloader();
    final controller = _controller(
      _FakeUpdateService(available: true),
      downloader: downloader,
      installer: _FakeApkInstaller(),
    );
    await controller.initialize();
    await _pumpScreen(tester, controller);
    final download = controller.downloadUpdate();
    await tester.pump();
    downloader.complete();
    await download;
    await tester.pump();
    await controller.installUpdate();
    await tester.pump();

    expect(find.text('Installer opened'), findsOneWidget);
    expect(find.textContaining('does not detect installation completion'),
        findsOneWidget);
  });

  testWidgets('update actions remain usable on a narrow large-text screen',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.reset);
    final controller = _controller(_FakeUpdateService(available: true));
    await controller.initialize();
    await _pumpScreen(tester, controller, textScale: 2);

    expect(tester.takeException(), isNull);
    await _reveal(tester, 'Download update');
    expect(find.text('Download update'), findsOneWidget);
    await _reveal(tester, 'Open release page');
    expect(find.text('Open release page'), findsOneWidget);
  });

  test('Android manifest declares network and package installer permissions',
      () {
    final manifest =
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync();
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.permission.REQUEST_INSTALL_PACKAGES'));
  });
}

UpdateController _controller(
  UpdateService service, {
  ApkDownloader? downloader,
  ApkInstaller? installer,
}) {
  return UpdateController(
    updateService: service,
    apkDownloader: downloader,
    apkInstaller: installer,
    packageInfo: _installed,
    readLastCheck: () async => null,
    writeLastCheck: (_) async {},
    isAndroid: () => true,
  );
}

Future<void> _reveal(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    240,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

Future<void> _pumpScreen(
  WidgetTester tester,
  UpdateController controller, {
  double textScale = 1,
}) async {
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildFortiqTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: UpdateScreen(controller: controller),
    ),
  );
  await tester.pump();
}

class _FakeUpdateService extends UpdateService {
  _FakeUpdateService({required this.available, this.error});

  final bool available;
  final UpdateException? error;

  @override
  Future<UpdateCheckResult> checkLatest({PackageInfo? installed}) async {
    if (error != null) throw error!;
    return UpdateCheckResult(
      latest: _update,
      installedVersion: _installed.version,
      installedBuild: int.parse(_installed.buildNumber),
      isUpdateAvailable: available,
    );
  }
}

class _FakeApkInstaller extends ApkInstaller {
  @override
  Future<InstallHandoffResult> handOff(String apkPath) async =>
      const InstallHandoffResult.handedOff();
}

class _FakeApkDownloader extends ApkDownloader {
  final _files = StreamController<ApkDownloadedFile>();

  @override
  Future<ApkDownloadedFile?> findVerifiedApk(
    UpdateInfo update, {
    CancelToken? cancelToken,
  }) async =>
      null;

  @override
  Future<void> cleanupOldApks({String? keepPath}) async {}

  @override
  Stream<ApkDownloadedFile> download(
    UpdateInfo update, {
    CancelToken? cancelToken,
    ApkProgressCallback? onProgress,
  }) {
    onProgress?.call(const ApkDownloadProgress(
      receivedBytes: 2621440,
      totalBytes: 5242880,
      bytesPerSecond: 1048576,
      eta: Duration(seconds: 3),
    ));
    return _files.stream;
  }

  void complete() {
    _files.add(const ApkDownloadedFile(
      apkPath: r'C:\cache\fortiq-1.2.3-4.apk',
      byteCount: 5242880,
      sha256:
          'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    ));
    _files.close();
  }
}
