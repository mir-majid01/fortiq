import '../models/base_layout.dart';
import '../repositories/base_repository.dart';

/// Bundled placeholder dataset mirroring the approved design's content.
///
/// The design canvas notes: "All base layouts, names, creators and numbers
/// are placeholder data." — this source reproduces exactly that content
/// (Obsidian Ring by Kaiden, 4.9 ★, "86 bases", …) so every screen matches
/// the reference artboards. All entries carry [BaseLayout.isSample] = true.
///
/// Curated design bases are hand-authored; the remaining entries are generated
/// deterministically (same LCG family as the preview illustrations) to fill
/// out 86 Home Village layouts — matching the "86 bases" count in the Explore
/// reference — plus 18 Builder Base layouts.
class SampleBaseRepository implements BaseRepository {
  @override
  Future<List<BaseLayout>> loadAll() async => _buildAll();

  @override
  String? get featuredId => 'obsidian-ring';

  @override
  List<String> get trendingIds =>
      const ['hollow-crown', 'iron-meridian', 'ashfall-core'];

  @override
  List<String> get recentIds =>
      const ['quiet-storm', 'basalt-gate', 'silent-meridian'];
}

const int _homeVillageCount = 86;
const int _builderBaseCount = 18;

String _timeAgo(Duration d) {
  final m = d.inMinutes;
  if (m < 60) return 'New · $m min ago';
  if (m < 24 * 60) return 'New · ${m ~/ 60} hour${m ~/ 60 == 1 ? '' : 's'} ago';
  final days = m ~/ (24 * 60);
  return days == 0 ? 'Today' : 'Updated ${days}d ago';
}

final List<BaseLayout> _designBases = [
  BaseLayout(
    id: 'obsidian-ring',
    name: 'Obsidian Ring',
    village: Village.home,
    hallLevel: 17,
    categories: ['War', 'Anti 3 Star'],
    layoutStyle: 'Ring',
    previewSeed: 3,
    creator: const Creator(name: 'Kaiden', verified: true),
    rating: 4.9,
    copies: 12440,
    updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
    updatedLabel: 'New · 2h ago',
    verified: true,
    description: 'Concentrated ring design built to defend the current meta.',
    isSample: true,
  ),
  BaseLayout(
    id: 'iron-meridian',
    name: 'Iron Meridian',
    village: Village.home,
    hallLevel: 17,
    categories: ['War', 'Anti 2 Star'],
    layoutStyle: 'Symmetrical',
    previewSeed: 8,
    creator: const Creator(name: 'Otto'),
    rating: 4.84,
    copies: 9800,
    updatedAt: DateTime.now().subtract(const Duration(days: 3)),
    updatedLabel: 'Updated 3d ago',
    verified: true,
    isSample: true,
  ),
  BaseLayout(
    id: 'hollow-crown',
    name: 'Hollow Crown',
    village: Village.home,
    hallLevel: 17,
    categories: ['Legend League'],
    layoutStyle: 'Island',
    previewSeed: 5,
    creator: const Creator(name: 'Mira.V', verified: true),
    rating: 4.82,
    copies: 12400,
    updatedAt: DateTime.now().subtract(const Duration(days: 7)),
    updatedLabel: 'Updated 1w ago',
    isSample: true,
  ),
  BaseLayout(
    id: 'ashfall-core',
    name: 'Ashfall Core',
    village: Village.home,
    hallLevel: 17,
    categories: ['Trophy'],
    layoutStyle: 'Box',
    previewSeed: 11,
    creator: const Creator(name: 'ForgeLab', verified: true),
    rating: 4.74,
    copies: 7200,
    updatedAt: DateTime.now().subtract(const Duration(days: 2)),
    updatedLabel: 'Updated 2d ago',
    verified: true,
    isSample: true,
  ),
  BaseLayout(
    id: 'quiet-storm',
    name: 'Quiet Storm',
    village: Village.home,
    hallLevel: 17,
    categories: ['CWL'],
    layoutStyle: 'Diamond',
    previewSeed: 14,
    creator: const Creator(name: 'Mira.V', verified: true),
    rating: 4.62,
    copies: 4400,
    updatedAt: DateTime.now().subtract(const Duration(minutes: 25)),
    updatedLabel: 'New · 25 min ago',
    isSample: true,
  ),
  BaseLayout(
    id: 'basalt-gate',
    name: 'Basalt Gate',
    village: Village.home,
    hallLevel: 14,
    categories: ['Farming'],
    layoutStyle: 'Box',
    previewSeed: 17,
    creator: const Creator(name: 'ForgeLab', verified: true),
    rating: 4.55,
    copies: 3800,
    updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
    updatedLabel: 'New · 1 hour ago',
    isSample: true,
  ),
  BaseLayout(
    id: 'silent-meridian',
    name: 'Silent Meridian',
    village: Village.home,
    hallLevel: 16,
    categories: ['Trophy'],
    layoutStyle: 'Symmetrical',
    previewSeed: 20,
    creator: const Creator(name: 'Kaiden', verified: true),
    rating: 4.6,
    copies: 5100,
    updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
    updatedLabel: 'Today',
    isSample: true,
  ),
];

const List<String> _adjectives = [
  'Amber', 'Ashen', 'Azure', 'Blazing', 'Bramble', 'Cinder', 'Cobalt',
  'Crimson', 'Duskfall', 'Ember', 'Falcon', 'Frost', 'Gilded', 'Granite',
  'Hallowed', 'Ironclad', 'Jade', 'Lunar', 'Marble', 'Molten', 'Nimbus',
  'Onyx', 'Pine', 'Quarry', 'Raven', 'Rustic', 'Sable', 'Solar', 'Thunder',
  'Verdant', 'Winter', 'Zephyr', 'Highland', 'Lowland', 'Storm', 'Starfall',
  'Moss', 'Fen', 'Gale', 'Emberfall',
];

const List<String> _nouns = [
  'Bastion', 'Citadel', 'Outpost', 'Spire', 'Vault', 'Keep', 'Haven',
  'Rampart', 'Bulwark', 'Parapet', 'Fortress', 'Redoubt', 'Stronghold',
  'Atrium', 'Labyrinth', 'Ward', 'Watch', 'Perch', 'Nest', 'Roost',
  'Pinnacle', 'Summit', 'Vanguard', 'Ridge', 'Canyon', 'Mesa', 'Refuge',
  'Embrace', 'Halo', 'Aegis', 'Crescent', 'Prism',
];

const List<Creator> _creators = [
  Creator(name: 'Kaiden', verified: true),
  Creator(name: 'Mira.V', verified: true),
  Creator(name: 'ForgeLab', verified: true),
  Creator(name: 'Nyla'),
  Creator(name: 'Otto'),
  Creator(name: 'Vex'),
  Creator(name: 'Harri'),
  Creator(name: 'BaseSmith'),
  Creator(name: 'Raju2K'),
  Creator(name: 'Cliff'),
  Creator(name: 'Yumi'),
  Creator(name: 'Dre'),
  Creator(name: 'Nova'),
  Creator(name: 'Pax'),
  Creator(name: 'Quill'),
  Creator(name: 'Sable'),
];

const List<List<String>> _hvCategories = [
  ['War'],
  ['War', 'Anti 3 Star'],
  ['CWL'],
  ['Trophy'],
  ['Farming'],
  ['Hybrid'],
  ['Legend League'],
  ['War', 'Anti 2 Star'],
  ['Ranked'],
  ['Farming', 'Hybrid'],
];

const List<List<String>> _bbCategories = [
  ['War'],
  ['Trophy'],
  ['Farming'],
  ['Hybrid'],
  ['Ranked'],
];

const List<String> _styles = [
  'Box', 'Diamond', 'Ring', 'Island', 'Symmetrical', 'Asymmetrical',
];

const List<int> _ageHours = [5, 26, 50, 96, 170, 340];

List<BaseLayout> _buildAll() {
  // Small deterministic shuffle source, same LCG family as the previews.
  var st = 4242;
  int nextInt(int max) {
    st = (st * 9301 + 49297) % 233280;
    return (st / 233280 * max).floor();
  }

  final now = DateTime.now();
  final result = <BaseLayout>[..._designBases];
  final usedNames = result.map((b) => b.name).toSet();

  BaseLayout generated(int n, Village village) {
    final adj = _adjectives[n % _adjectives.length];
    var nounIdx = (n * 7 + 3) % _nouns.length;
    var name = '$adj ${_nouns[nounIdx]}';
    while (usedNames.contains(name)) {
      nounIdx = (nounIdx + 1) % _nouns.length;
      name = '$adj ${_nouns[nounIdx]}';
    }
    usedNames.add(name);

    final isHome = village == Village.home;
    final hallLevel = isHome ? 11 + (n * 7) % 8 : 6 + n % 5;
    final cats = isHome
        ? _hvCategories[n % _hvCategories.length]
        : _bbCategories[n % _bbCategories.length];
    final creator = _creators[nextInt(_creators.length)];
    final ageH = _ageHours[nextInt(_ageHours.length)];
    final updated = now.subtract(Duration(hours: ageH));

    return BaseLayout(
      id: 'sample-${isHome ? 'hv' : 'bb'}-${n + 1}',
      name: name,
      village: village,
      hallLevel: hallLevel,
      categories: cats,
      layoutStyle: _styles[(n * 5 + 2) % _styles.length],
      previewSeed: 21 + (n * 13) % 78,
      creator: creator,
      rating: isHome ? 4.0 + nextInt(7) / 10.0 : 4.0 + nextInt(8) / 10.0,
      copies: 300 + nextInt(6400),
      updatedAt: updated,
      updatedLabel: _timeAgo(now.difference(updated)),
      verified: creator.verified,
      isSample: true,
    );
  }

  for (var n = 0; n < _homeVillageCount - _designBases.length; n++) {
    result.add(generated(n, Village.home));
  }
  for (var n = 0; n < _builderBaseCount; n++) {
    result.add(generated(n, Village.builder));
  }
  return result;
}
