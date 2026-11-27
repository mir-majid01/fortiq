/// Stable, numeric app-version components. Build metadata does not affect
/// precedence; prerelease versions are intentionally not accepted.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch);

  factory AppVersion.parse(String value) {
    final match = RegExp(
      r'^v?(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)'
      r'(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$',
    ).firstMatch(value);
    if (match == null) {
      throw const FormatException('Expected a stable semantic version');
    }
    return AppVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  final int major;
  final int minor;
  final int patch;

  @override
  int compareTo(AppVersion other) {
    final majorOrder = major.compareTo(other.major);
    if (majorOrder != 0) return majorOrder;
    final minorOrder = minor.compareTo(other.minor);
    if (minorOrder != 0) return minorOrder;
    return patch.compareTo(other.patch);
  }

  @override
  String toString() => '$major.$minor.$patch';
}

enum UpdateFailureCode {
  noRelease,
  invalidRelease,
  untrustedUrl,
  network,
  rateLimited,
  http,
  storage,
  checksumMissing,
  checksumInvalid,
  sizeMismatch,
  checksumMismatch,
  downloadFailed,
  cancelled,
  unsupportedPlatform,
  installerFailed,
  unknown,
}

/// A recoverable updater failure suitable for display by the UI layer.
class UpdateException implements Exception {
  const UpdateException({
    required this.code,
    required this.message,
    this.rateLimitReset,
    this.cause,
  });

  final UpdateFailureCode code;
  final String message;
  final DateTime? rateLimitReset;
  final Object? cause;

  bool get isCancellation => code == UpdateFailureCode.cancelled;

  @override
  String toString() => 'UpdateException($code): $message';
}

/// Only GitHub's public release and asset hosts are accepted.
const trustedUpdateHosts = <String>{
  'api.github.com',
  'github.com',
  'objects.githubusercontent.com',
};

/// Validates a URL immediately before it is handed to an HTTP client.
Uri validateUpdateUrl(String rawUrl) {
  final uri = Uri.tryParse(rawUrl);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      !trustedUpdateHosts.contains(uri.host) ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443)) {
    throw const UpdateException(
      code: UpdateFailureCode.untrustedUrl,
      message: 'The update URL is not a trusted HTTPS GitHub URL.',
    );
  }
  return uri;
}

/// Immutable metadata for one stable public GitHub release.
class UpdateInfo {
  const UpdateInfo({
    required this.versionName,
    required this.versionCode,
    required this.publishedAt,
    required this.releaseName,
    required this.notes,
    required this.apkName,
    required this.apkSize,
    required this.apkUrl,
    required this.checksumUrl,
    required this.apkSha256,
    required this.releaseUrl,
  });

  factory UpdateInfo.fromJson(Map<String, dynamic> json) {
    try {
      if (json['draft'] != false || json['prerelease'] != false) {
        throw const UpdateException(
          code: UpdateFailureCode.invalidRelease,
          message: 'Only stable, published releases can be used for updates.',
        );
      }

      final rawTag = json['tag_name'];
      if (rawTag is! String) {
        throw const FormatException('tag_name is missing');
      }
      AppVersion.parse(rawTag);
      final versionName = rawTag.startsWith('v') ? rawTag.substring(1) : rawTag;
      final versionCode = _versionCodeFromJson(
        json['version_code'] ?? _buildFromTag(rawTag),
      );

      final rawPublishedAt = json['published_at'];
      final publishedAt =
          rawPublishedAt is String ? DateTime.tryParse(rawPublishedAt) : null;
      if (rawPublishedAt != null && publishedAt == null) {
        throw const FormatException('published_at is invalid');
      }

      final rawAssets = json['assets'];
      if (rawAssets is! List) {
        throw const FormatException('assets are missing');
      }
      final assets = rawAssets
          .whereType<Map>()
          .map((asset) => Map<String, dynamic>.from(asset))
          .toList(growable: false);
      final apk = _assetNamed(assets, 'app-debug.apk');
      final checksum = _assetNamed(assets, 'app-debug.apk.sha256');
      final apkSize = apk['size'];
      if (apkSize is! int || apkSize <= 0) {
        throw const FormatException('APK byte count is missing or invalid');
      }

      final apkUrl = _requiredString(apk, 'browser_download_url');
      final checksumUrl = _requiredString(checksum, 'browser_download_url');
      final releaseUrl = _requiredString(json, 'html_url');
      validateUpdateUrl(apkUrl);
      validateUpdateUrl(checksumUrl);
      validateUpdateUrl(releaseUrl);

      final rawName = json['name'];
      final rawNotes = json['body'];
      if (rawName != null && rawName is! String) {
        throw const FormatException('release name is invalid');
      }
      if (rawNotes != null && rawNotes is! String) {
        throw const FormatException('release notes are invalid');
      }

      return UpdateInfo(
        versionName: versionName,
        versionCode: versionCode,
        publishedAt: publishedAt,
        releaseName: rawName is String && rawName.trim().isNotEmpty
            ? rawName
            : versionName,
        notes: rawNotes as String? ?? '',
        apkName: 'app-debug.apk',
        apkSize: apkSize,
        apkUrl: apkUrl,
        checksumUrl: checksumUrl,
        apkSha256: _advertisedDigest(apk['digest']),
        releaseUrl: releaseUrl,
      );
    } on UpdateException {
      rethrow;
    } catch (error) {
      throw UpdateException(
        code: UpdateFailureCode.invalidRelease,
        message: 'Release metadata is invalid.',
        cause: error,
      );
    }
  }

  final String versionName;
  final int? versionCode;
  final DateTime? publishedAt;
  final String releaseName;
  final String notes;
  final String apkName;
  final int apkSize;
  final String apkUrl;
  final String checksumUrl;

  /// GitHub's advertised digest when supplied. The downloader still fetches
  /// and validates the mandatory `.sha256` asset before enabling install.
  final String apkSha256;
  final String releaseUrl;

  AppVersion get semanticVersion => AppVersion.parse(versionName);
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.latest,
    required this.installedVersion,
    required this.installedBuild,
    required this.isUpdateAvailable,
  });

  final UpdateInfo latest;
  final String installedVersion;
  final int? installedBuild;
  final bool isUpdateAvailable;
}

Map<String, dynamic> _assetNamed(
  List<Map<String, dynamic>> assets,
  String name,
) {
  for (final asset in assets) {
    if (asset['name'] == name) return asset;
  }
  throw FormatException('Required asset $name is missing');
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$key is missing');
  }
  return value;
}

int? _buildFromTag(String tag) {
  final match = RegExp(r'\+(\d+)$').firstMatch(tag);
  return match == null ? null : int.parse(match.group(1)!);
}

int? _versionCodeFromJson(Object? value) {
  if (value == null) return null;
  final parsed = value is int ? value : int.tryParse(value.toString());
  if (parsed == null || parsed < 0) {
    throw const FormatException('version_code is invalid');
  }
  return parsed;
}

String _advertisedDigest(Object? value) {
  if (value == null) return '';
  if (value is! String) {
    throw const FormatException('asset digest is invalid');
  }
  if (value.isEmpty) return '';
  final match = RegExp(
    r'^sha256:([0-9a-fA-F]{64})$',
    caseSensitive: false,
  ).firstMatch(value);
  if (match == null) {
    throw const FormatException('asset digest is invalid');
  }
  return match.group(1)!.toLowerCase();
}
