import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/core/widgets/base_preview_image.dart';
import 'package:fortiq/data/models/base_layout.dart';
import 'package:fortiq/features/base_preview/base_preview.dart';
import 'package:fortiq/features/base_preview/layout_preview.dart';

class _PreviewBuildContext implements BuildContext {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('real entry without a preview shows an honest unavailable state',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: BasePreviewImage(imageUrl: null)),
      ),
    );

    expect(find.text('Preview unavailable'), findsOneWidget);
    expect(find.byType(BasePreview), findsNothing);
  });

  testWidgets('compact real preview failure fits thumbnail constraints',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: BasePreviewImage(imageUrl: null),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
  });

  test('user-owned preview selects FileImage before network imagery', () {
    const widget = BasePreviewImage(
      imageUrl: 'https://example.test/remote.png',
      localImagePath: r'C:\private\preview.png',
    );
    final image = widget.build(_PreviewBuildContext()) as Image;
    expect(image.image, isA<FileImage>());
    expect((image.image as FileImage).file.path, r'C:\private\preview.png');
  });

  testWidgets('layout preview keeps sample art and uses imagery for real data',
      (tester) async {
    const sample = BaseLayout(
      id: 'sample',
      name: 'Sample',
      village: Village.home,
      hallLevel: 17,
      categories: ['War'],
      layoutStyle: 'Ring',
      previewSeed: 3,
      creator: Creator(name: 'Sample Creator'),
      isSample: true,
    );
    const real = BaseLayout(
      id: 'real',
      name: 'Real',
      village: Village.home,
      hallLevel: 17,
      categories: ['War'],
      layoutStyle: '',
      previewSeed: 0,
      creator: Creator(name: ''),
      isSample: false,
      imageUrl: 'https://example.test/real.png',
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LayoutPreview(base: sample)),
      ),
    );
    expect(find.byType(BasePreview), findsOneWidget);
    expect(find.byType(BasePreviewImage), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LayoutPreview(base: real)),
      ),
    );
    expect(find.byType(BasePreview), findsNothing);
    expect(find.byType(BasePreviewImage), findsOneWidget);
  });

  testWidgets('failed real preview offers retry without procedural fallback',
      (tester) async {
    var retries = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BasePreviewImage(
            imageUrl: 'https://example.invalid/preview.png',
            onRetry: () => retries++,
          ),
        ),
      ),
    );
    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    final context = tester.element(find.byType(CachedNetworkImage));
    final errorWidget =
        image.errorWidget!(context, image.imageUrl, Exception());
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: errorWidget)));

    expect(find.text('Preview unavailable'), findsOneWidget);
    expect(find.byType(BasePreview), findsNothing);
    await tester.tap(find.text('Retry'));
    expect(retries, 1);
  });
}
