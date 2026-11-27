import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/base_layout.dart';
import '../models/catalogue_rights.dart';
import '../sources/open_layout_link.dart';

class ImportedBaseStore {
  ImportedBaseStore({Directory? directory}) : _directory = directory;

  static const _metadataKey = 'fortiq.imported_bases.v1';
  static const _sourceId = 'user-import';

  final Directory? _directory;

  Future<Directory> get _root async {
    final configured = _directory;
    if (configured != null) return configured;
    return getApplicationSupportDirectory();
  }

  Future<List<BaseLayout>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_metadataKey);
    if (raw == null || raw.isEmpty) return const [];
    final parsed = jsonDecode(raw) as Map<String, dynamic>;
    if (parsed['schemaVersion'] != 1 || parsed['bases'] is! List) {
      throw const FormatException('Unsupported imported catalogue schema');
    }
    final result = <BaseLayout>[];
    for (final value in parsed['bases'] as List) {
      if (value is! Map) {
        throw const FormatException('Invalid imported catalogue record');
      }
      final base = _fromJson(Map<String, Object?>.from(value));
      final preview = File(base.localImagePath!);
      if (await preview.exists()) result.add(base);
    }
    return List.unmodifiable(result);
  }

  Future<BaseLayout> importBase({
    required String link,
    required String name,
    String? attribution,
    String? description,
    required File preview,
  }) async {
    final parsedLink = OpenLayoutLink.parse(link);
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const FormatException('Enter a name for this base.');
    }
    if (!await preview.exists()) {
      throw const FormatException('Choose a preview image first.');
    }
    final existing = await load();
    if (existing.any((base) => base.gameLink == parsedLink.originalUrl)) {
      throw StateError('This official layout link is already imported.');
    }

    final digest = sha256.convert(utf8.encode(parsedLink.originalUrl));
    final id = 'user-${digest.toString().substring(0, 20)}';
    final extension = _extension(preview.path);
    final root = await _root;
    final previewDirectory = Directory('${root.path}/imported_previews');
    await previewDirectory.create(recursive: true);
    final target = File('${previewDirectory.path}/$id.$extension');
    await preview.copy(target.path);
    final now = DateTime.now();
    final base = BaseLayout(
      id: id,
      name: trimmedName,
      village: parsedLink.village,
      hallLevel: parsedLink.hallLevel,
      categories: const [],
      layoutStyle: '',
      previewSeed: 0,
      creator: const Creator(name: ''),
      isSample: false,
      localImagePath: target.path,
      gameLink: parsedLink.originalUrl,
      description: description?.trim(),
      sourceId: _sourceId,
      sourceAttribution: attribution?.trim(),
      sourceUrl: parsedLink.originalUrl,
      sourceAdded: now.toUtc().toIso8601String(),
      addedAt: now,
      updatedAt: now,
      rightsStatus: CatalogueRightsStatus.userOwned,
    );
    try {
      await _save([...existing, base]);
    } catch (_) {
      if (await target.exists()) await target.delete();
      rethrow;
    }
    return base;
  }

  Future<void> delete(String id) async {
    final existing = await load();
    final target = existing.where((base) => base.id == id).firstOrNull;
    await _save(existing.where((base) => base.id != id).toList());
    if (target?.localImagePath case final path?) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  Future<void> _save(List<BaseLayout> bases) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = jsonEncode({
      'schemaVersion': 1,
      'bases': bases.map(_toJson).toList(),
    });
    final saved = await prefs.setString(_metadataKey, raw);
    if (!saved) throw StateError('Could not persist imported bases.');
  }

  static String _extension(String path) {
    final value = path.toLowerCase();
    if (value.endsWith('.jpg') || value.endsWith('.jpeg')) return 'jpg';
    if (value.endsWith('.webp')) return 'webp';
    if (value.endsWith('.png')) return 'png';
    throw const FormatException('Choose a JPG, PNG, or WebP preview.');
  }

  static Map<String, Object?> _toJson(BaseLayout base) => {
        'id': base.id,
        'name': base.name,
        'village': base.village.name,
        'hallLevel': base.hallLevel,
        'categories': base.categories,
        'layoutStyle': base.layoutStyle,
        'previewSeed': base.previewSeed,
        'localImagePath': base.localImagePath,
        'gameLink': base.gameLink,
        'description': base.description,
        'sourceId': base.sourceId,
        'sourceAttribution': base.sourceAttribution,
        'sourceUrl': base.sourceUrl,
        'sourceAdded': base.sourceAdded,
        'addedAt': base.addedAt?.toIso8601String(),
        'updatedAt': base.updatedAt?.toIso8601String(),
        'rightsStatus': base.rightsStatus.wireValue,
      };

  static BaseLayout _fromJson(Map<String, Object?> json) {
    String required(String key) {
      final value = json[key];
      if (value is! String || value.isEmpty) {
        throw FormatException('Imported base is missing "$key"');
      }
      return value;
    }

    final village = Village.values.byName(required('village'));
    final hallLevel = json['hallLevel'];
    final categories = json['categories'];
    final previewSeed = json['previewSeed'];
    final rights = CatalogueRightsStatus.fromJson(json['rightsStatus']);
    if (hallLevel != null && hallLevel is! int ||
        categories is! List ||
        previewSeed is! int ||
        rights != CatalogueRightsStatus.userOwned) {
      throw const FormatException('Imported base metadata is invalid');
    }
    return BaseLayout(
      id: required('id'),
      name: required('name'),
      village: village,
      hallLevel: hallLevel as int?,
      categories: List<String>.unmodifiable(categories.cast<String>()),
      layoutStyle: json['layoutStyle'] as String? ?? '',
      previewSeed: previewSeed,
      creator: const Creator(name: ''),
      isSample: false,
      localImagePath: required('localImagePath'),
      gameLink: required('gameLink'),
      description: json['description'] as String?,
      sourceId: required('sourceId'),
      sourceAttribution: json['sourceAttribution'] as String?,
      sourceUrl: required('sourceUrl'),
      sourceAdded: json['sourceAdded'] as String?,
      addedAt: DateTime.tryParse(json['addedAt'] as String? ?? ''),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? ''),
      rightsStatus: rights,
    );
  }
}
