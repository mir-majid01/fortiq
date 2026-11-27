import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:fortiq/features/updates/models/update_info.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Fetches and validates the latest stable public Fortiq release.
class UpdateService {
  UpdateService({Dio? dio, PackageInfo? packageInfo})
      : _dio = dio ?? Dio(),
        _packageInfo = packageInfo {
    final adapter = _dio.httpClientAdapter;
    if (adapter is! TrustedRedirectAdapter) {
      _dio.httpClientAdapter = TrustedRedirectAdapter(adapter);
    }
  }

  static const latestReleaseUrl =
      'https://api.github.com/repos/mir-majid01/fortiq/releases/latest';
  static const requestHeaders = <String, String>{
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'Fortiq-Android-Updater',
  };

  final Dio _dio;
  final PackageInfo? _packageInfo;

  Future<UpdateCheckResult> checkLatest({PackageInfo? installed}) async {
    final package =
        installed ?? _packageInfo ?? await PackageInfo.fromPlatform();
    late final AppVersion installedVersion;
    late final int? installedBuild;
    try {
      installedVersion = AppVersion.parse(package.version);
      installedBuild = _parseInstalledBuild(package.buildNumber);
    } catch (error) {
      throw UpdateException(
        code: UpdateFailureCode.invalidRelease,
        message: 'Installed app version metadata is invalid.',
        cause: error,
      );
    }

    try {
      final response = await _dio.get<dynamic>(
        latestReleaseUrl,
        options: Options(
          headers: requestHeaders,
          responseType: ResponseType.json,
          followRedirects: false,
          receiveTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 15),
        ),
      );
      final latest = UpdateInfo.fromJson(_responseMap(response.data));
      final versionOrder = latest.semanticVersion.compareTo(installedVersion);
      final buildOrder = latest.versionCode == null || installedBuild == null
          ? 0
          : latest.versionCode!.compareTo(installedBuild);
      final isUpdateAvailable =
          versionOrder > 0 || (versionOrder == 0 && buildOrder > 0);

      return UpdateCheckResult(
        latest: latest,
        installedVersion: package.version,
        installedBuild: installedBuild,
        isUpdateAvailable: isUpdateAvailable,
      );
    } on UpdateException {
      rethrow;
    } on DioException catch (error) {
      throw _mapDioException(error);
    } catch (error) {
      throw UpdateException(
        code: UpdateFailureCode.invalidRelease,
        message: 'Release metadata is invalid.',
        cause: error,
      );
    }
  }

  static Map<String, dynamic> _responseMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final decoded = jsonDecode(data);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    throw const FormatException('Expected a JSON object');
  }

  static int? _parseInstalledBuild(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^\d+$').hasMatch(trimmed)) {
      throw const FormatException('Build number is not numeric');
    }
    return int.parse(trimmed);
  }

  static UpdateException _mapDioException(DioException error) {
    final adapterError = error.error;
    if (adapterError is UpdateException) return adapterError;
    if (error.type == DioExceptionType.cancel) {
      return const UpdateException(
        code: UpdateFailureCode.cancelled,
        message: 'Update check cancelled.',
        cause: null,
      );
    }
    final status = error.response?.statusCode;
    if (status == 404) {
      return const UpdateException(
        code: UpdateFailureCode.noRelease,
        message: 'No public release is available yet.',
      );
    }
    if (status == 403 || status == 429) {
      return UpdateException(
        code: UpdateFailureCode.rateLimited,
        message:
            'GitHub rate limit reached. Try again later or open the release page.',
        rateLimitReset: _rateLimitReset(error.response?.headers),
      );
    }
    if (status != null) {
      return UpdateException(
        code: UpdateFailureCode.http,
        message: 'GitHub returned HTTP $status while checking for updates.',
      );
    }
    return const UpdateException(
      code: UpdateFailureCode.network,
      message: 'Could not reach GitHub. Check your connection and try again.',
    );
  }

  static DateTime? _rateLimitReset(Headers? headers) {
    final raw = headers?.value('x-ratelimit-reset');
    if (raw == null) return null;
    final seconds = int.tryParse(raw);
    if (seconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }
}

/// Applies the HTTPS/host allowlist to every redirect, not only the initial
/// URL. Requests are made with `followRedirects: false` so no destination is
/// contacted before validation.
class TrustedRedirectAdapter implements HttpClientAdapter {
  TrustedRedirectAdapter(this._delegate);

  final HttpClientAdapter _delegate;
  static const _maxRedirects = 5;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    return _fetch(options, requestStream, cancelFuture, 0);
  }

  Future<ResponseBody> _fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
    int redirectCount,
  ) async {
    validateUpdateUrl(options.uri.toString());
    if (options.cancelToken?.isCancelled ?? false) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.cancel,
      );
    }

    final response =
        await _delegate.fetch(options, requestStream, cancelFuture);
    for (final redirect in response.redirects ?? const <RedirectRecord>[]) {
      validateUpdateUrl(redirect.location.toString());
    }

    if (!_isRedirect(response.statusCode)) return response;
    final location = _header(response.headers, 'location');
    if (location == null || location.isEmpty) return response;
    if (redirectCount >= _maxRedirects) {
      throw const UpdateException(
        code: UpdateFailureCode.network,
        message: 'The update server returned too many redirects.',
      );
    }

    await response.stream.take(64 * 1024).drain<void>();
    final nextUri = options.uri.resolve(location);
    validateUpdateUrl(nextUri.toString());
    final headers = Map<String, dynamic>.from(options.headers)
      ..removeWhere((key, _) => key.toLowerCase() == 'host');
    final nextOptions = options.copyWith(
      path: nextUri.toString(),
      baseUrl: '',
      method: response.statusCode == 303 ? 'GET' : options.method,
      headers: headers,
      followRedirects: false,
    );
    return _fetch(nextOptions, null, cancelFuture, redirectCount + 1);
  }

  @override
  void close({bool force = false}) => _delegate.close(force: force);

  static bool _isRedirect(int status) =>
      status == 301 ||
      status == 302 ||
      status == 303 ||
      status == 307 ||
      status == 308;

  static String? _header(Map<String, List<String>> headers, String name) {
    for (final entry in headers.entries) {
      if (entry.key.toLowerCase() == name && entry.value.isNotEmpty) {
        return entry.value.first;
      }
    }
    return null;
  }
}
