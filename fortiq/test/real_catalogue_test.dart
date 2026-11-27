import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/app/state/app_state.dart';
import 'package:fortiq/app/theme/app_theme.dart';
import 'package:fortiq/core/widgets/state_scope.dart';
import 'package:fortiq/data/models/base_layout.dart';
import 'package:fortiq/data/models/catalogue_rights.dart';
import 'package:fortiq/data/models/filters.dart';
import 'package:fortiq/data/repositories/base_repository.dart';
import 'package:fortiq/data/repositories/composite_base_repository.dart';
import 'package:fortiq/data/repositories/imported_base_store.dart';
import 'package:fortiq/data/repositories/queries.dart';
import 'package:fortiq/data/sources/clash_bases_source.dart';
import 'package:fortiq/data/sources/sample_base_source.dart';
import 'package:fortiq/features/explore/explore_screen.dart';
import 'package:fortiq/features/home/home_screen.dart';
import 'package:fortiq/features/home/widgets/featured_base_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _homeLink =
    'https://link.clashofclans.com/en?action=OpenLayout&id=TH17%3AHV%3AAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAA';
const _builderLink =
    'https://link.clashofclans.com/fi?action=OpenLayout&id=TH17%3AWB%3AAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAA';
const _unknownVillageLink =
    'https://link.clashofclans.com/en?action=OpenLayout&id=TH17%3AXX%3AAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAA';

Map<String, Object?> _record({
  required String id,
  required String name,
  required String link,
  required String image,
  String type = 'War',
  int townHall = 17,
  String? description,
  String? builder,
  List<String> tags = const [],
  String? added,
  String? sourceId,
}) =>
    {
      'id': id,
      'name': name,
      'town_hall': townHall,
      'type': type,
      'link': link,
      'description': description,
      'builder': builder,
      'tags': tags,
      'added': added,
      'image': image,
      if (sourceId != null) 'source_id': sourceId,
    };

Map<String, Object?> _sourceRights({
  String id = 'clash-bases',
  String content = 'cleared',
  String previews = 'cleared',
}) =>
    {
      'id': id,
      'name': 'Explicit test fixture',
      'upstreamUrl': 'https://example.test/catalogue',
      'license': 'Fixture permission',
      'licenseNotice': 'Fixture licence notice',
      'contentRedistribution': content,
      'previewRedistribution': previews,
      'evidence': 'Synthetic cleared fixture for tests only',
    };

ClashBasesCatalogRepository _repository(
  List<Map<String, Object?>> records, {
  List<Map<String, Object?>>? sources,
}) {
  final assets = {
    'rights.json': jsonEncode({
      'schemaVersion': 1,
      'unofficialDisclosure': 'Unofficial test fixture; no endorsement.',
      'sources': sources ?? [_sourceRights()],
    }),
    'catalogue.json': jsonEncode({'schemaVersion': 1, 'bases': records}),
  };
  return ClashBasesCatalogRepository(
    assetBundle: _FixtureAssetBundle(assets),
    catalogueAssetPath: 'catalogue.json',
    rightsManifestAssetPath: 'rights.json',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('mapper preserves the source name and forwards URLs unchanged', () {
    final record = _record(
      id: 'cleared-home',
      name: 'Cleared Home (TH17)',
      link: _homeLink,
      image: 'https://example.test/cleared-home.png',
      description: 'A cleared test fixture.',
      builder: 'Fixture Author',
      tags: const ['anti-3-star', 'open-source'],
      added: '2026-11-20',
    );

    final base = ClashBasesCatalogRepository.fromJson(record);

    expect(base.name, 'Cleared Home (TH17)');
    expect(base.gameLink, _homeLink);
    expect(base.imageUrl, 'https://example.test/cleared-home.png');
    expect(base.description, 'A cleared test fixture.');
    expect(base.sourceCategories, ['War']);
    expect(base.sourceTags, ['anti-3-star', 'open-source']);
    expect(base.sourceAttribution, 'Fixture Author');
    expect(base.sourceUrl, _homeLink);
    expect(base.sourceTownHall, 17);
    expect(base.sourceAdded, '2026-11-20');
    expect(base.addedAt, DateTime(2026, 11, 20));
    expect(base.creator.name, isEmpty,
        reason: 'upstream attribution is not proof of an individual builder');
    expect(base.rightsStatus, CatalogueRightsStatus.unresolved);
  });

  test('WB payload selects Builder Base without inventing a Builder Hall level',
      () {
    final base = ClashBasesCatalogRepository.fromJson(_record(
      id: 'cleared-builder',
      name: 'Cleared Builder',
      link: _builderLink,
      image: 'https://example.test/cleared-builder.png',
      townHall: 17,
    ));

    expect(base.village, Village.builder);
    expect(base.hallLevel, isNull);
    expect(base.hallBadge, 'Builder Base');
  });

  test('HV payload supplies the Home hall while original town_hall is retained',
      () {
    final base = ClashBasesCatalogRepository.fromJson(_record(
      id: 'payload-hall',
      name: 'Payload Hall',
      link: _homeLink,
      image: 'https://example.test/payload-hall.png',
      townHall: 12,
    ));

    expect(base.village, Village.home);
    expect(base.hallLevel, 17);
    expect(base.sourceTownHall, 12);
  });

  test('an undocumented village marker stays unknown', () {
    final base = ClashBasesCatalogRepository.fromJson(_record(
      id: 'unknown-village',
      name: 'Unknown Village',
      link: _unknownVillageLink,
      image: 'https://example.test/unknown-village.png',
    ));

    expect(base.village, Village.unknown);
    expect(base.hallLevel, isNull);
    expect(base.hallBadge, 'Unknown village');
  });

  test('category mapping is explicit and lossless', () {
    const expected = {
      'War': 'War',
      'Farm': 'Farming',
      'Trophy': 'Trophy',
      'Hybrid': 'Hybrid',
    };
    for (final entry in expected.entries) {
      final base = ClashBasesCatalogRepository.fromJson(_record(
        id: 'mapped-${entry.key}',
        name: 'Mapped ${entry.key}',
        link: _homeLink,
        image: 'https://example.test/mapped-${entry.key}.png',
        type: entry.key,
      ));
      expect(base.categories, [entry.value]);
      expect(base.sourceCategories, [entry.key]);
    }

    for (final type in ['Progress', 'Fun', 'Home Village', 'FutureType']) {
      final base = ClashBasesCatalogRepository.fromJson(_record(
        id: 'unmapped-$type',
        name: 'Unmapped $type',
        link: _homeLink,
        image: 'https://example.test/unmapped-$type.png',
        type: type,
      ));
      expect(base.categories, isEmpty);
      expect(base.sourceCategories, [type]);
    }
  });

  test('secondary taxonomy comes only from explicit source evidence', () {
    final tagged = ClashBasesCatalogRepository.fromJson(_record(
      id: 'tagged-taxonomy',
      name: 'Neutral Name',
      link: _homeLink,
      image: 'https://example.test/tagged-taxonomy.png',
      tags: const ['anti-2-star', 'CWL', 'ring'],
      description: 'Ranked Legend League showcase.',
    ));
    expect(tagged.categories,
        ['War', 'Anti 2 Star', 'CWL', 'Legend League', 'Ranked']);
    expect(tagged.layoutStyle, 'Ring');
    expect(tagged.sourceTags, ['anti-2-star', 'CWL', 'ring']);

    final nameOnly = ClashBasesCatalogRepository.fromJson(_record(
      id: 'name-only',
      name: 'Anti 3 Star CWL Legend Ring',
      link: _homeLink,
      image: 'https://example.test/name-only.png',
    ));
    expect(nameOnly.categories, ['War']);
    expect(nameOnly.layoutStyle, isEmpty);

    final incidental = ClashBasesCatalogRepository.fromJson(_record(
      id: 'incidental-taxonomy',
      name: 'Neutral Name',
      link: _homeLink,
      image: 'https://example.test/incidental-taxonomy.png',
      tags: const ['sandbox', 'bring'],
      description: 'An unranked storyline.',
    ));
    expect(incidental.categories, ['War']);
    expect(incidental.layoutStyle, isEmpty);
  });

  test('mapper does not fabricate ratings copies verification or layout style',
      () {
    final base = ClashBasesCatalogRepository.fromJson(_record(
      id: 'cleared-no-stats',
      name: 'Cleared No Stats',
      link: _homeLink,
      image: 'https://example.test/cleared-no-stats.png',
    ));

    expect(base.rating, isNull);
    expect(base.copies, isNull);
    expect(base.verified, isFalse);
    expect(base.creator.verified, isFalse);
    expect(base.layoutStyle, isEmpty);
    expect(base.previewSeed, 0);
    expect(base.creatorHandle, 'Source unavailable');
  });

  test('production uses the packaged real catalogue, never samples', () async {
    final repository = repositoryProvider();

    expect(repository, isA<CompositeBaseRepository>());
    expect(repository, isNot(isA<SampleBaseRepository>()));
    expect((repository as CompositeBaseRepository).remote,
        isA<ClashBasesCatalogRepository>());

    final bases = await repository.loadAll();

    expect(bases, isNotEmpty);
    expect(bases.length, greaterThan(1000));
    expect(bases.every((base) => !base.isSample), isTrue);
    expect(bases.every((base) => base.gameLink != null), isTrue);
    expect(repository.isCatalogueUnavailable, isFalse);
  });

  test('packaged rights evidence clears the attributed source and retains notice',
      () async {
    final raw = await rootBundle.loadString(
      ClashBasesCatalogRepository.defaultRightsManifestAssetPath,
    );
    final manifest = CatalogueRightsManifest.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );

    expect(manifest.sources, hasLength(1));
    expect(manifest.clearedSources, hasLength(1));
    expect(manifest.sources.single.contentRedistribution,
        CatalogueRightsStatus.cleared);
    expect(manifest.sources.single.previewRedistribution,
        CatalogueRightsStatus.cleared);
    expect(manifest.sources.single.licenseNotice,
        contains('Copyright (c) 2026 Clash Bases contributors'));
    expect(manifest.sources.single.evidence, contains('MIT-licensed'));
    expect(manifest.unofficialDisclosure, contains('not affiliated with'));
    expect(manifest.unofficialDisclosure, contains('endorsed by Supercell'));
  });

  test('legacy unresolved catalogue path is not packaged', () async {
    await expectLater(
      rootBundle.loadString('assets/data/clash_bases_catalog.json'),
      throwsA(isA<FlutterError>()),
    );
  });

  test('cleared fixture loads every unique record with exact source metadata',
      () async {
    final records = [
      _record(
        id: 'cleared-home',
        name: 'Cleared Home (TH17)',
        link: _homeLink,
        image: 'https://example.test/cleared-home.png',
        builder: 'Fixture Home Source',
        tags: const ['Needle-Tag', 'anti-3-star'],
        added: '2026-11-20',
      ),
      _record(
        id: 'cleared-builder',
        name: 'Cleared Builder',
        link: _builderLink,
        image: 'https://example.test/cleared-builder.png',
        type: 'Farm',
        builder: 'Fixture Builder Source',
        tags: const ['showcase'],
        added: '2026-11-21',
      ),
    ];
    final repository = _repository(records);

    final bases = await repository.loadAll();

    expect(bases, hasLength(2));
    expect(bases.map((base) => base.id).toSet(), hasLength(2));
    expect(bases.map((base) => base.gameLink).toSet(), hasLength(2));
    expect(bases.map((base) => base.imageUrl).toSet(), hasLength(2));
    expect(bases.first.gameLink, _homeLink);
    expect(bases.first.sourceUrl, _homeLink);
    expect(bases.first.sourceTags, ['Needle-Tag', 'anti-3-star']);
    expect(bases.first.sourceAttribution, 'Fixture Home Source');
    expect(bases.first.rightsStatus, CatalogueRightsStatus.cleared);
    expect(bases.last.categories, ['Farming']);
    expect(bases.last.hallLevel, isNull);
    expect(repository.isCatalogueUnavailable, isFalse);
    expect(repository.featuredId, isNull);
    expect(repository.trendingIds, isEmpty);
    expect(repository.recentIds, ['cleared-builder', 'cleared-home']);
  });

  test('unresolved source records are excluded from production', () async {
    final repository = _repository(
      [
        _record(
          id: 'unresolved',
          name: 'Unresolved',
          link: _homeLink,
          image: 'https://example.test/unresolved.png',
        )
      ],
      sources: [_sourceRights(content: 'unresolved', previews: 'unresolved')],
    );

    expect(await repository.loadAll(), isEmpty);
    expect(repository.isCatalogueUnavailable, isTrue);
  });

  test('unknown sources and unresolved previews are excluded', () async {
    final unknownSource = _repository(
      [
        _record(
          id: 'unknown-source',
          name: 'Unknown Source',
          link: _homeLink,
          image: 'https://example.test/unknown-source.png',
          sourceId: 'not-in-manifest',
        )
      ],
    );
    final unresolvedPreview = _repository(
      [
        _record(
          id: 'unresolved-preview',
          name: 'Unresolved Preview',
          link: _builderLink,
          image: 'https://example.test/unresolved-preview.png',
        )
      ],
      sources: [_sourceRights(previews: 'unresolved')],
    );

    expect(await unknownSource.loadAll(), isEmpty);
    expect(await unresolvedPreview.loadAll(), isEmpty);
  });

  test('duplicate cleared IDs links and images fail closed', () async {
    final first = _record(
      id: 'first',
      name: 'First',
      link: _homeLink,
      image: 'https://example.test/first.png',
    );
    final duplicateCases = <String, List<Map<String, Object?>>>{
      'id': [
        first,
        _record(
          id: 'first',
          name: 'Second',
          link: _builderLink,
          image: 'https://example.test/second.png',
        ),
      ],
      'link': [
        first,
        _record(
          id: 'second',
          name: 'Second',
          link: _homeLink,
          image: 'https://example.test/second.png',
        ),
      ],
      'image': [
        first,
        _record(
          id: 'second',
          name: 'Second',
          link: _builderLink,
          image: 'https://example.test/first.png',
        ),
      ],
    };

    for (final entry in duplicateCases.entries) {
      await expectLater(
        _repository(entry.value).loadAll(),
        throwsA(isA<FormatException>()),
        reason: 'duplicate ${entry.key} must not enter the cleared catalogue',
      );
    }
  });

  test('unsupported catalogue schema fails closed', () async {
    final assets = {
      'rights.json': jsonEncode({
        'schemaVersion': 1,
        'unofficialDisclosure': 'Unofficial fixture.',
        'sources': [_sourceRights()],
      }),
      'catalogue.json': jsonEncode({
        'schemaVersion': 2,
        'bases': [
          _record(
            id: 'future-schema',
            name: 'Future Schema',
            link: _homeLink,
            image: 'https://example.test/future-schema.png',
          ),
        ],
      }),
    };
    final repository = ClashBasesCatalogRepository(
      assetBundle: _FixtureAssetBundle(assets),
      catalogueAssetPath: 'catalogue.json',
      rightsManifestAssetPath: 'rights.json',
    );

    await expectLater(repository.loadAll(), throwsA(isA<FormatException>()));
  });

  test('malformed rights evidence fails closed', () async {
    final assets = {
      'rights.json': jsonEncode({
        'schemaVersion': 1,
        'unofficialDisclosure': 'Unofficial fixture.',
        'sources': [
          {
            'id': 'clash-bases',
            'name': 'Missing evidence',
            'upstreamUrl': 'https://example.test',
            'license': 'MIT',
            'licenseNotice': 'Notice',
            'contentRedistribution': 'cleared',
            'previewRedistribution': 'cleared',
          },
        ],
      }),
      'catalogue.json': jsonEncode({
        'bases': [
          _record(
            id: 'must-not-load',
            name: 'Must Not Load',
            link: _homeLink,
            image: 'https://example.test/must-not-load.png',
          ),
        ],
      }),
    };
    final repository = ClashBasesCatalogRepository(
      assetBundle: _FixtureAssetBundle(assets),
      catalogueAssetPath: 'catalogue.json',
      rightsManifestAssetPath: 'rights.json',
    );

    await expectLater(repository.loadAll(), throwsA(isA<FormatException>()));
  });

  test('search includes preserved tags and attribution without inferred stats',
      () {
    final bases = [
      ClashBasesCatalogRepository.fromJson(_record(
        id: 'searchable',
        name: 'Searchable',
        link: _homeLink,
        image: 'https://example.test/searchable.png',
        builder: 'Attribution Needle',
        tags: const ['Tag Needle'],
      )),
    ];

    expect(
      queryBases(bases, query: 'tag needle', filters: ExploreFilters())
          .single
          .id,
      'searchable',
    );
    expect(
      queryBases(
        bases,
        query: 'attribution needle',
        filters: ExploreFilters(),
      ).single.id,
      'searchable',
    );
  });

  test('hall filters exclude unknown levels rather than guessing', () {
    final builder = ClashBasesCatalogRepository.fromJson(_record(
      id: 'unknown-hall',
      name: 'Unknown Hall',
      link: _builderLink,
      image: 'https://example.test/unknown-hall.png',
    ));

    expect(
      queryBases(
        [builder],
        filters: ExploreFilters(village: Village.builder, hallLevels: {10}),
      ),
      isEmpty,
    );
  });

  testWidgets('unclassified cleared entries remain usable on Home',
      (tester) async {
    final repository = _repository([
      _record(
        id: 'unclassified-builder',
        name: 'Unclassified Builder',
        link: _builderLink,
        image: 'https://example.test/unclassified-builder.png',
        type: 'Progress',
        townHall: 17,
      ),
    ]);
    final state = AppState(repository: repository);
    addTearDown(state.dispose);
    await tester.runAsync(state.load);
    state.selectVillage(Village.builder);

    await tester.pumpWidget(
      StateScope(
        state: state,
        child: MaterialApp(
          theme: buildFortiqTheme(),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(FeaturedBaseCard), findsOneWidget);
    expect(find.text('Unclassified · Source unavailable'), findsOneWidget);
  });

  testWidgets('empty cleared catalogue shows an honest unavailable state',
      (tester) async {
    final state = AppState(
      repository: CompositeBaseRepository(
        remote: _repository(const []),
        imports: ImportedBaseStore(directory: Directory.systemTemp),
      ),
    );
    addTearDown(state.dispose);
    await tester.runAsync(state.load);

    expect(state.catalogueUnavailable, isTrue);
    expect(state.greetingTitle, 'Catalogue unavailable');

    await tester.pumpWidget(
      StateScope(
        state: state,
        child: MaterialApp(
          theme: buildFortiqTheme(),
          home: const ExploreScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalogue-unavailable')), findsOneWidget);
    expect(find.text('No rights-cleared bases are available.'), findsOneWidget);
    expect(find.text('No bases match these filters'), findsNothing);
    expect(find.text('Reset filters'), findsNothing);
    expect(find.text('Obsidian Ring'), findsNothing);

    await tester.pumpWidget(
      StateScope(
        state: state,
        child: MaterialApp(
          theme: buildFortiqTheme(),
          home: const HomeScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('catalogue-unavailable')), findsOneWidget);
    expect(find.text('Catalogue unavailable'), findsOneWidget);
    expect(find.text('Fresh TH 16 layouts today'), findsNothing);
    expect(find.byType(FeaturedBaseCard), findsNothing);
    expect(find.text('Obsidian Ring'), findsNothing);
  });
}

class _FixtureAssetBundle extends CachingAssetBundle {
  _FixtureAssetBundle(this.assets);

  final Map<String, String> assets;

  @override
  Future<ByteData> load(String key) async {
    final value = assets[key];
    if (value == null) throw FlutterError('Missing fixture asset: $key');
    return ByteData.sublistView(Uint8List.fromList(utf8.encode(value)));
  }
}
