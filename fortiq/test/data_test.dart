import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/data/models/base_layout.dart';
import 'package:fortiq/data/models/filters.dart';
import 'package:fortiq/data/repositories/queries.dart';
import 'package:fortiq/data/sources/sample_base_source.dart';

void main() {
  late List<BaseLayout> bases;

  setUp(() async {
    bases = await SampleBaseRepository().loadAll();
  });

  test('sample dataset: 86 Home Village + 18 Builder Base layouts', () {
    expect(bases.where((b) => b.village == Village.home).length, 86,
        reason: 'Explore reference shows "86 bases" by default');
    expect(bases.where((b) => b.village == Village.builder).length, 18);
  });

  test('ids are unique', () {
    expect(bases.map((b) => b.id).toSet().length, bases.length);
    expect(bases.map((b) => b.name).toSet().length, bases.length);
  });

  test('top-rated default ordering matches the Explore reference', () {
    final result = queryBases(
      bases,
      filters: ExploreFilters(),
      sort: BaseSort.topRated,
    );
    // All sample bases are Home Village here; the first four results are the
    // curated design bases in the reference order.
    expect(
      result.take(4).map((b) => b.id).toList(),
      ['obsidian-ring', 'iron-meridian', 'hollow-crown', 'ashfall-core'],
    );
    expect(result.first.rating!.toStringAsFixed(1), '4.9');
  });

  test('filters: TH 17 + War + Anti 3 Star + Ring returns Obsidian Ring', () {
    final f = ExploreFilters()
      ..hallLevels.add(17)
      ..categories.addAll(['War', 'Anti 3 Star'])
      ..styles.add('Ring');
    final result = queryBases(bases, filters: f);
    expect(result.map((b) => b.id), contains('obsidian-ring'));
    expect(f.activeGroupCount, 3);
  });

  test('village filter excludes the other village', () {
    final result = queryBases(
      bases,
      filters: ExploreFilters()..village = Village.builder,
    );
    expect(result, everyElement(predicate<BaseLayout>(
        (b) => b.village == Village.builder)));
  });

  test('changing village clears incompatible hall selections', () {
    final filters = ExploreFilters()..hallLevels.addAll({16, 17});

    filters.village = Village.builder;

    expect(filters.hallLevels, isEmpty);
    expect(queryBases(bases, filters: filters), hasLength(18));
  });

  test('All keeps both villages without counting as a filter group', () {
    final filters = ExploreFilters()..village = null;

    expect(queryBases(bases, filters: filters), hasLength(104));
    expect(filters.activeGroupCount, 0);
  });

  test('verified-only filter keeps verified creators', () {
    final result = queryBases(
      bases,
      filters: ExploreFilters()..verifiedOnly = true,
    );
    expect(result, everyElement(predicate<BaseLayout>((b) => b.creator.verified)));
  });

  test('search finds names and creators, exact names float to top', () {
    final result = queryBases(
      bases,
      query: 'obsidian',
      filters: ExploreFilters(),
    );
    expect(result.first.id, 'obsidian-ring');

    final creators = queryBases(
      bases,
      query: 'kaiden',
      filters: ExploreFilters(),
    );
    expect(creators, isNotEmpty);
    expect(creators.every((b) => b.creator.name == 'Kaiden'), isTrue);
  });

  test('most-copied sort puts curated leaders first', () {
    final result = queryBases(
      bases,
      filters: ExploreFilters(),
      sort: BaseSort.mostCopied,
    );
    expect(result.first.id, 'obsidian-ring');
    expect(result[1].id, 'hollow-crown');
    expect(result[2].id, 'iron-meridian');
  });

  test('newest sort surfaces the recent design bases first', () {
    final result = queryBases(
      bases,
      filters: ExploreFilters(),
      sort: BaseSort.newest,
    );
    expect(result.first.id, 'quiet-storm');
    expect(result[1].id, 'basalt-gate');
  });

  test('freshness filter respects updatedAt', () {
    final result = queryBases(
      bases,
      filters: ExploreFilters()..freshness = Freshness.sevenDays,
    );
    expect(result, isNotEmpty);
  });

  test('curated home sections resolve', () {
    final repo = SampleBaseRepository();
    expect(repo.featuredId, 'obsidian-ring');
    expect(repo.trendingIds, ['hollow-crown', 'iron-meridian', 'ashfall-core']);
    expect(repo.recentIds, ['quiet-storm', 'basalt-gate', 'silent-meridian']);
  });
}
