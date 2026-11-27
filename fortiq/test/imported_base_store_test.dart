import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/data/models/base_layout.dart';
import 'package:fortiq/data/models/catalogue_rights.dart';
import 'package:fortiq/data/repositories/imported_base_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _link =
    'https://link.clashofclans.com/en?action=OpenLayout&id=TH17%3AHV%3AAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAA';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late ImportedBaseStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    directory = await Directory.systemTemp.createTemp('fortiq-import-test');
    store = ImportedBaseStore(directory: directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test('import persists metadata and a private preview across relaunch',
      () async {
    final source = File('${directory.path}/source.png')
      ..writeAsBytesSync([1, 2, 3, 4]);

    final base = await store.importBase(
      link: _link,
      name: 'My Imported Base',
      attribution: 'Me',
      preview: source,
    );
    final restored = await ImportedBaseStore(directory: directory).load();

    expect(restored, hasLength(1));
    expect(restored.single.id, base.id);
    expect(restored.single.name, 'My Imported Base');
    expect(restored.single.village, Village.home);
    expect(restored.single.hallLevel, 17);
    expect(restored.single.gameLink, _link);
    expect(restored.single.rightsStatus, CatalogueRightsStatus.userOwned);
    expect(restored.single.isSample, isFalse);
    expect(await File(restored.single.localImagePath!).exists(), isTrue);
    expect(await File(restored.single.localImagePath!).readAsBytes(),
        [1, 2, 3, 4]);
  });

  test('duplicate official links are rejected without a second record',
      () async {
    final source = File('${directory.path}/source.png')
      ..writeAsBytesSync([1, 2, 3]);
    await store.importBase(link: _link, name: 'First', preview: source);

    await expectLater(
      store.importBase(link: _link, name: 'Duplicate', preview: source),
      throwsA(isA<StateError>()),
    );
    expect(await store.load(), hasLength(1));
  });

  test('delete removes metadata and the private preview file', () async {
    final source = File('${directory.path}/source.png')
      ..writeAsBytesSync([1, 2, 3]);
    final base =
        await store.importBase(link: _link, name: 'Delete me', preview: source);

    await store.delete(base.id);

    expect(await store.load(), isEmpty);
    expect(await File(base.localImagePath!).exists(), isFalse);
  });
}
