import '../models/base_layout.dart';
import '../models/filters.dart';

/// Search + filter + sort pipeline shared by Explore and its tests.
///
/// When searching, exact name matches float to the top of the results.
List<BaseLayout> queryBases(
  List<BaseLayout> bases, {
  String query = '',
  required ExploreFilters filters,
  BaseSort sort = BaseSort.topRated,
  int limit = 0,
}) {
  final q = query.trim().toLowerCase();
  Iterable<BaseLayout> result = bases.where(filters.matches);
  if (q.isNotEmpty) {
    result = result.where((b) {
      final haystack = [
        b.name,
        b.creator.name,
        b.layoutStyle,
        ...b.categories,
      ].join(' ').toLowerCase();
      return haystack.contains(q);
    });
  }

  final List<BaseLayout> exact, rest;
  if (q.isNotEmpty) {
    exact = result.where((b) => b.name.toLowerCase() == q).toList();
    rest = result.where((b) => b.name.toLowerCase() != q).toList();
  } else {
    exact = <BaseLayout>[];
    rest = result.toList();
  }

  final cmp = _comparator(sort);
  exact.sort(cmp);
  rest.sort(cmp);
  final merged = [...exact, ...rest];
  return limit > 0 ? merged.take(limit).toList() : merged;
}

Comparator<BaseLayout> _comparator(BaseSort sort) {
  switch (sort) {
    case BaseSort.topRated:
      return (a, b) {
        final r = (b.rating ?? -1).compareTo(a.rating ?? -1);
        if (r != 0) return r;
        return (b.copies ?? 0).compareTo(a.copies ?? 0);
      };
    case BaseSort.mostCopied:
      return (a, b) {
        final r = (b.copies ?? 0).compareTo(a.copies ?? 0);
        if (r != 0) return r;
        return (b.rating ?? -1).compareTo(a.rating ?? -1);
      };
    case BaseSort.newest:
      return (a, b) {
        final at = a.updatedAt, bt = b.updatedAt;
        if (at == null && bt == null) return 0;
        if (at == null) return 1;
        if (bt == null) return -1;
        return bt.compareTo(at);
      };
  }
}
