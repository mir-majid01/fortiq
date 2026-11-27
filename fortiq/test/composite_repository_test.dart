import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/data/models/base_layout.dart';
import 'package:fortiq/data/models/catalogue_rights.dart';
import 'package:fortiq/data/repositories/base_repository.dart';
import 'package:fortiq/data/repositories/composite_base_repository.dart';
import 'package:fortiq/data/repositories/imported_base_store.dart';
import 'package:fortiq/data/sources/clash_bases_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _link =
    'https://link.clashofclans.com/en?action=OpenLayout&id=TH17%3AHV%3AAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAA';
const _remoteLink =
    'https://link.clashofclans.com/en?action=OpenLayout&id=TH18%3AHV%3AAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAA';

class _RemoteRepository implements BaseRepository {
  _RemoteRepository(this.bases);

  final List<BaseLayout> bases;

  @override
  Future<List<BaseLayout>> loadAll() async => bases;

  @override
  bool get isCatalogueUnavailable => bases.isEmpty;

  @override
  String? get featuredId => null;

  @override
  List<String> get trendingIds => const [];

  @override
  List<String> get recentIds => bases.map((base) => base.id).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late ImportedBaseStore imports;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('fortiq-composite-test');
    imports = ImportedBaseStore(directory: directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('merges user imports with rights-cleared remote records', () async {
    final source = File('${directory.path}/preview.png')
      ..writeAsBytesSync([1, 2, 3]);
    final imported = await imports.importBase(
      link: _link,
      name: 'Imported',
      preview: source,
    );
    final remote = ClashBasesCatalogRepository.fromJson({
      'id': 'remote',
      'name': 'Cleared Remote',
      'town_hall': 18,
      'type': 'War',
      'link': _remoteLink,
      'image': 'https://example.test/remote.png',
    }, rightsStatus: CatalogueRightsStatus.cleared);
    final repository = CompositeBaseRepository(
      remote: _RemoteRepository([remote]),
      imports: imports,
    );

    final bases = await repository.loadAll();

    expect(bases.map((base) => base.id), ['remote', imported.id]);
    expect(repository.isCatalogueUnavailable, isFalse);
    expect(repository.recentIds, contains(imported.id));
  });

  test('rejects a user import that duplicates a cleared remote link', () async {
    final source = File('${directory.path}/preview.png')
      ..writeAsBytesSync([1, 2, 3]);
    final remote = ClashBasesCatalogRepository.fromJson({
      'id': 'remote',
      'name': 'Cleared Remote',
      'town_hall': 17,
      'type': 'War',
      'link': _link,
      'image': 'https://example.test/remote.png',
    }, rightsStatus: CatalogueRightsStatus.cleared);
    final repository = CompositeBaseRepository(
      remote: _RemoteRepository([remote]),
      imports: imports,
    );

    await expectLater(
      repository.importBase(link: _link, name: 'Duplicate', preview: source),
      throwsA(isA<StateError>()),
    );
    expect(await imports.load(), isEmpty);
  });

  test('production provider is composite and never falls back to samples', () {
    final repository = repositoryProvider();
    expect(repository, isA<CompositeBaseRepository>());
    expect(repository, isNot(isA<ClashBasesCatalogRepository>()));
  });
}
