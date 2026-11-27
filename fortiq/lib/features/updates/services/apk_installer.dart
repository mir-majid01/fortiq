import 'dart:io';

import 'package:flutter/services.dart';

typedef ApkInstallInvoker = Future<dynamic> Function(String apkPath);

enum InstallHandoffStatus { handedOff, failed }

/// Describes only whether Android's installer was handed off. It deliberately
/// cannot represent an installation-completion result.
class InstallHandoffResult {
  const InstallHandoffResult({
    required this.status,
    required this.message,
  });

  const InstallHandoffResult.handedOff()
      : status = InstallHandoffStatus.handedOff,
        message = 'Handed off to the system installer.';

  final InstallHandoffStatus status;
  final String message;
}

/// Android package-installer boundary. All native-channel outcomes are normalized
/// to a handoff or a recoverable failure; this service never throws.
class ApkInstaller {
  ApkInstaller({
    ApkInstallInvoker? install,
    bool Function()? isAndroid,
  })  : _install = install ?? _invokeNativeInstaller,
        _isAndroid = isAndroid ?? (() => Platform.isAndroid);

  static const _channel = MethodChannel('fortiq/apk_installer');

  static Future<bool?> _invokeNativeInstaller(String path) =>
      _channel.invokeMethod<bool>(
        'install',
        {'path': path},
      );

  final ApkInstallInvoker _install;
  final bool Function() _isAndroid;

  Future<InstallHandoffResult> handOff(String apkPath) async {
    if (!_isAndroid()) {
      return const InstallHandoffResult(
        status: InstallHandoffStatus.failed,
        message: 'Updates are managed by the App Store on iOS.',
      );
    }

    final file = File(apkPath);
    try {
      if (!await file.exists() || await file.length() == 0) {
        return const InstallHandoffResult(
          status: InstallHandoffStatus.failed,
          message:
              'The verified APK is no longer available. Download it again.',
        );
      }
      final response = await _install(file.absolute.path);
      if (response == true ||
          (response is Map && response['isSuccess'] == true)) {
        return const InstallHandoffResult.handedOff();
      }
      if (response is Map) {
        final detail = response['errorMessage'];
        if (detail is String && detail.trim().isNotEmpty) {
          return InstallHandoffResult(
            status: InstallHandoffStatus.failed,
            message: detail,
          );
        }
      }
      return const InstallHandoffResult(
        status: InstallHandoffStatus.failed,
        message: 'The system installer could not be opened. Try again.',
      );
    } catch (error) {
      return InstallHandoffResult(
        status: InstallHandoffStatus.failed,
        message: 'The system installer could not be opened: $error',
      );
    }
  }
}
