import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/core/icons/svg_path.dart';
import 'package:fortiq/main.dart' as app;
import 'package:image/image.dart' as img;

const _background = '#0B0D10';
const _brightGold = '#E6BF68';
const _gold = '#D6A84F';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('canonical Fortiq launch artwork', () {
    test('uses the exact three SVG paths and fills from the reference', () {
      final reference = _read('../reference/Splash.dc.html');
      final canonical = _read('assets/branding/fortiq_emblem.svg');

      expect(canonical, contains('viewBox="0 0 100 128"'));
      expect(canonical, isNot(contains('background')));
      for (final line in reference.split('\n').skip(20).take(3)) {
        final path = RegExp(r'd="([^"]+)"').firstMatch(line)!.group(1)!;
        final fill = RegExp(r'fill="(#[0-9A-Fa-f]{6})"')
            .firstMatch(line)!
            .group(1)!
            .toUpperCase();
        expect(canonical, contains('d="$path"'),
            reason: 'The canonical path must match reference line $line');
        expect(canonical, contains('fill="$fill"'));
      }
      expect(canonical, contains('fill-rule="evenodd"'));
      final fills = RegExp(r'fill="(#[0-9A-Fa-f]{6})"')
          .allMatches(canonical)
          .map((match) => match.group(1)!.toUpperCase())
          .toList();
      expect(fills, const [_brightGold, _gold, _brightGold]);
      expect(canonical, isNot(contains('#0B0D10')));
    });

    test('declares the required dark flutter_native_splash mapping', () {
      final pubspec = _read('pubspec.yaml');
      expect(
          RegExp(r'^flutter_native_splash:', multiLine: true)
              .allMatches(pubspec)
              .length,
          1,
          reason: 'There must be only one native splash system');
      expect(pubspec, contains('    - assets/branding/'));
      for (final line in <String>[
        '  color: "$_background"',
        '  color_dark: "$_background"',
        '  image: assets/branding/fortiq_splash.png',
        '  image_dark: assets/branding/fortiq_splash.png',
        '  android_gravity: center',
        '  ios_content_mode: center',
        '  fullscreen: true',
        '    color: "$_background"',
        '    color_dark: "$_background"',
        '    image: assets/branding/fortiq_splash_android12.png',
        '    image_dark: assets/branding/fortiq_splash_android12.png',
      ]) {
        expect(pubspec, contains(line),
            reason: 'Missing required setting: $line');
      }
    });

    test('splash PNGs exactly match the canonical vector render', () async {
      const fixtures =
          <({String path, Size canvas, Size vector, Offset origin})>[
        (
          path: 'assets/branding/fortiq_splash.png',
          canvas: Size(408, 520),
          vector: Size(368, 472),
          origin: Offset(20, 24),
        ),
        (
          path: 'assets/branding/fortiq_splash_ios.png',
          canvas: Size(306, 390),
          vector: Size(276, 354),
          origin: Offset(15, 18),
        ),
        (
          path: 'assets/branding/fortiq_splash_android12.png',
          canvas: Size(1152, 1152),
          vector: Size(368, 472),
          origin: Offset(392, 340),
        ),
      ];
      for (final fixture in fixtures) {
        final image = await _decode(fixture.path);
        expect(image.width, fixture.canvas.width.toInt());
        expect(image.height, fixture.canvas.height.toInt());
        final expected = await _renderCanonicalEmblem(
          fixture.canvas,
          vector: fixture.vector,
          origin: fixture.origin,
        );
        try {
          _expectExactPixels(
            await _rgba(image),
            await _rgba(expected),
            fixture.path,
            width: image.width,
          );
        } finally {
          image.dispose();
          expected.dispose();
        }
      }
    });

    test('Android 12 art is mask-safe and matches Flutter crest scale',
        () async {
      final image =
          await _decode('assets/branding/fortiq_splash_android12.png');
      final pixels = await _rgba(image);
      const safeRadius = 384.0; // Android 12's 768 px central safe circle.
      var painted = 0;
      for (var y = 0; y < image.height; y++) {
        for (var x = 0; x < image.width; x++) {
          final offset = (y * image.width + x) * 4;
          if (pixels[offset + 3] == 0) continue;
          painted++;
          final dx = x + 0.5 - image.width / 2;
          final dy = y + 0.5 - image.height / 2;
          expect(dx * dx + dy * dy, lessThanOrEqualTo(safeRadius * safeRadius),
              reason: 'Painted pixel ($x, $y) crosses the Android 12 mask');
        }
      }
      // The 1152 px source represents Android's 288 dp icon canvas. A
      // 368x472 vector therefore renders at the same 92x118 dp size as
      // FortiqEmblem and SplashScreen instead of being rescaled at handoff.
      expect(painted, greaterThan(80000));
      expect(painted, lessThan(100000));
      image.dispose();
    });

    test('generated splash resources exactly match density derivatives',
        () async {
      const densities = <String, double>{
        'mdpi': 1,
        'hdpi': 1.5,
        'xhdpi': 2,
        'xxhdpi': 3,
        'xxxhdpi': 4,
      };
      for (final qualifier in <String>['', '-night']) {
        for (final density in densities.entries) {
          for (final kind in <({String source, String name})>[
            (
              source: 'assets/branding/fortiq_splash.png',
              name: 'splash.png',
            ),
            (
              source: 'assets/branding/fortiq_splash_android12.png',
              name: 'android12splash.png',
            ),
          ]) {
            final source = img.decodePng(File(kind.source).readAsBytesSync())!;
            final expected = img.copyResize(
              source,
              width: source.width * density.value ~/ 4,
              height: source.height * density.value ~/ 4,
              interpolation: img.Interpolation.average,
            );
            final path = 'android/app/src/main/res/'
                'drawable$qualifier-${density.key}/${kind.name}';
            final actual = img.decodePng(File(path).readAsBytesSync())!;
            expect(actual.width, expected.width, reason: path);
            expect(actual.height, expected.height, reason: path);
            _expectExactImagePixels(actual, expected, path);
          }
        }
      }

      final source = img.decodePng(
          File('assets/branding/fortiq_splash.png').readAsBytesSync())!;
      for (final scale in <int>[1, 2, 3]) {
        final expected = img.copyResize(
          source,
          width: source.width * scale ~/ 4,
          height: source.height * scale ~/ 4,
          interpolation: img.Interpolation.average,
        );
        for (final dark in <bool>[false, true]) {
          final name = dark ? 'LaunchImageDark' : 'LaunchImage';
          final suffix = scale == 1 ? '' : '@${scale}x';
          final path = 'ios/Runner/Assets.xcassets/LaunchImage.imageset/'
              '$name$suffix.png';
          final actual = img.decodePng(File(path).readAsBytesSync())!;
          expect(actual.width, expected.width, reason: path);
          expect(actual.height, expected.height, reason: path);
          _expectExactImagePixels(actual, expected, path);
        }
      }
    });
  });

  test('entrypoint preserves the splash until initialized root handoff', () {
    final source = _read('lib/main.dart');
    final preserve = source.indexOf('FlutterNativeSplash.preserve');
    final initialize = source.indexOf('await initializeFortiq()');
    final runApp = source.indexOf('runApp(const FortiqLaunch(');
    expect(preserve, greaterThanOrEqualTo(0));
    expect(initialize, greaterThan(preserve));
    expect(runApp, greaterThan(initialize));
    expect(source.substring(runApp),
        contains('onFirstFrame: FlutterNativeSplash.remove'));
    expect(
        source,
        isNot(matches(RegExp(
            r'runApp\([\s\S]*?\);\s*FlutterNativeSplash\.remove\(\);'))));
  });

  group('native launch surfaces', () {
    test('Android legacy launch and normal backgrounds resolve to #0B0D10',
        () async {
      for (final qualifier in <String>['', '-night']) {
        final styles =
            _read('android/app/src/main/res/values$qualifier/styles.xml');
        final normal = RegExp('<style name="NormalTheme"[\\s\\S]*?</style>')
            .firstMatch(styles)!
            .group(0)!;
        expect(normal, contains('android:windowBackground'));
        final normalColor =
            RegExp(r'@color/([A-Za-z0-9_]+)').firstMatch(normal)!.group(1)!;
        expect(_androidColor(normalColor, qualifier), _background,
            reason: 'NormalTheme in values$qualifier must be dark');

        final launch = RegExp('<style name="LaunchTheme"[\\s\\S]*?</style>')
            .firstMatch(styles)!
            .group(0)!;
        expect(launch, contains('@drawable/launch_background'));
      }
      final resourceRoot = Directory('android/app/src/main/res');
      for (final directory in resourceRoot.listSync().whereType<Directory>()) {
        final launch = File('${directory.path}/launch_background.xml');
        if (!launch.existsSync()) continue;
        final source = launch.readAsStringSync();
        expect(source, contains('@drawable/background'),
            reason: '${directory.path} must use the generated dark background');
        expect(source, contains('@drawable/splash'),
            reason: '${directory.path} must show the Fortiq emblem');
        final background = File('${directory.path}/background.png');
        final image = await _decode(background.path);
        expect(
            _isBackgroundPixel(await _rgba(image), 0, 0, image.width), isTrue,
            reason: '${background.path} must be #0B0D10');
      }
    });

    test('Android 12 splash resources exist and use the branded assets', () {
      final styles = _read('android/app/src/main/res/values-v31/styles.xml');
      expect(styles,
          contains('android:windowSplashScreenBackground">$_background<'));
      expect(styles, contains('android:windowSplashScreenAnimatedIcon'));
      expect(styles, contains('@drawable/android12splash'));
      expect(
          styles,
          contains(
              'android:windowBackground">@color/fortiq_launch_background'));
      final manifest = _read('android/app/src/main/AndroidManifest.xml');
      expect(manifest, contains('io.flutter.embedding.android.NormalTheme'));
      expect(manifest, contains('android:resource="@style/NormalTheme"'));
      final resources = Directory('android/app/src/main/res')
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path)
          .toList();
      expect(
          resources
              .where(
                  (path) => path.replaceAll('\\', '/').endsWith('/splash.png'))
              .length,
          greaterThanOrEqualTo(10),
          reason: 'Light and dark legacy densities must have splash logos');
      expect(
          resources
              .where((path) =>
                  path.replaceAll('\\', '/').endsWith('/android12splash.png'))
              .length,
          greaterThanOrEqualTo(10),
          reason: 'Light and dark Android 12 densities must have splash logos');
    });

    test('iOS launch and root storyboards are dark and show LaunchImage', () {
      for (final path in <String>[
        'ios/Runner/Base.lproj/LaunchScreen.storyboard',
        'ios/Runner/Base.lproj/Main.storyboard',
      ]) {
        final source = _read(path);
        final colors = RegExp(r'<color key="backgroundColor"([^>]*)/>')
            .allMatches(source)
            .map((match) => match.group(1)!)
            .toList();
        expect(colors, isNotEmpty,
            reason: '$path needs an explicit background');
        for (final attributes in colors) {
          expect(_storyboardColor(attributes), const [11, 13, 16]);
        }
      }
      expect(_read('ios/Runner/Base.lproj/LaunchScreen.storyboard'),
          contains('image="LaunchImage"'));
      final contents = jsonDecode(_read(
              'ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json'))
          as Map<String, dynamic>;
      final images = contents['images'] as List<dynamic>;
      expect(images, hasLength(6),
          reason: 'Light and dark variants each need 1x, 2x, and 3x images');
      for (final entry in images.cast<Map<String, dynamic>>()) {
        final file = File('ios/Runner/Assets.xcassets/LaunchImage.imageset/'
                '${entry['filename']}')
            .readAsBytesSync();
        expect(file.length, greaterThan(1000),
            reason: '${entry['filename']} is still a stock placeholder');
      }
    });

    test('Android and iOS launcher icons are branded, not stock Flutter',
        () async {
      expect(_read('android/app/src/main/AndroidManifest.xml'),
          contains('android:label="Fortiq"'));
      final adaptive =
          _read('android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml');
      expect(adaptive, contains('@color/fortiq_launch_background'));
      expect(adaptive, contains('@mipmap/ic_launcher_foreground'));
      final foreground = await _decode(
          'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher_foreground.png');
      final foregroundPixels = await _rgba(foreground);
      const safeRadius = 432 * 33 / 108;
      for (var y = 0; y < foreground.height; y++) {
        for (var x = 0; x < foreground.width; x++) {
          if (foregroundPixels[(y * foreground.width + x) * 4 + 3] == 0) {
            continue;
          }
          final dx = x + 0.5 - foreground.width / 2;
          final dy = y + 0.5 - foreground.height / 2;
          expect(dx * dx + dy * dy, lessThanOrEqualTo(safeRadius * safeRadius),
              reason: 'Adaptive icon pixel ($x, $y) crosses its safe zone');
        }
      }

      for (final density in <String, int>{
        'mdpi': 48,
        'hdpi': 72,
        'xhdpi': 96,
        'xxhdpi': 144,
        'xxxhdpi': 192,
      }.entries) {
        final path = 'android/app/src/main/res/mipmap-${density.key}/'
            'ic_launcher.png';
        final image = await _decode(path);
        expect(image.width, density.value);
        expect(image.height, density.value);
        final pixels = await _rgba(image);
        expect(_isBackgroundPixel(pixels, 0, 0, image.width), isTrue);
        expect(_hasGold(pixels), isTrue,
            reason: '$path must show the Fortiq crest');
      }

      final contents = jsonDecode(_read(
              'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json'))
          as Map<String, dynamic>;
      for (final entry in (contents['images'] as List<dynamic>)
          .cast<Map<String, dynamic>>()) {
        final image = await _decode(
            'ios/Runner/Assets.xcassets/AppIcon.appiconset/${entry['filename']}');
        final pixels = await _rgba(image);
        expect(_isBackgroundPixel(pixels, 0, 0, image.width), isTrue,
            reason: '${entry['filename']} must use the opaque Fortiq canvas');
        expect(_hasGold(pixels), isTrue,
            reason: '${entry['filename']} must show the Fortiq crest');
      }
    });
  });

  testWidgets('native splash release waits for the first branded root frame',
      (tester) async {
    var releases = 0;
    final launch = app.FortiqLaunch(
      onFirstFrame: () => releases++,
      child: const ColoredBox(
        key: Key('branded-root'),
        color: Color(0xFF0B0D10),
      ),
    );

    expect(releases, 0, reason: 'Construction must not release the splash');
    await tester.pumpWidget(launch);
    expect(find.byKey(const Key('branded-root')), findsOneWidget);
    expect(releases, 1, reason: 'The first completed frame releases once');

    await tester.pump();
    expect(releases, 1, reason: 'Later frames must not release again');
  });
}

Future<ui.Image> _renderCanonicalEmblem(
  Size canvasSize, {
  required Size vector,
  required Offset origin,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final scale = math.min(vector.width / 100, vector.height / 128);
  canvas
    ..translate(
      origin.dx + (vector.width - 100 * scale) / 2,
      origin.dy + (vector.height - 128 * scale) / 2,
    )
    ..scale(scale);
  final bright = ui.Paint()..color = const ui.Color(0xFFE6BF68);
  final gold = ui.Paint()..color = const ui.Color(0xFFD6A84F);
  canvas
    ..drawPath(
      parseSvgPath(
          'M21.05 24.5V9H31.55V14.5H36.85V3.5H47.35V14.5H52.65V3.5H63.15V14.5H68.45V9H78.95V24.5Z'),
      bright,
    )
    ..drawPath(
      parseSvgPath(
        'M5 30H95V93L50 124.5L5 93ZM15.75 40.5H84.25V87.4L50 111.4L15.75 87.4Z',
        fillType: ui.PathFillType.evenOdd,
      ),
      gold,
    )
    ..drawPath(
      parseSvgPath(
          'M21.05 45.8H78.95V84.65L68.45 92V56.5H63.15V95.72L50 104.93L36.85 95.72V56.5H31.55V92L21.05 84.65Z'),
      bright,
    );
  final picture = recorder.endRecording();
  final image = await picture.toImage(
      canvasSize.width.toInt(), canvasSize.height.toInt());
  picture.dispose();
  return image;
}

void _expectExactPixels(
  Uint8List actual,
  Uint8List expected,
  String path, {
  int? width,
}) {
  expect(actual.length, expected.length, reason: path);
  var mismatches = 0;
  var firstMismatch = -1;
  for (var i = 0; i < actual.length; i++) {
    if (actual[i] == expected[i]) continue;
    mismatches++;
    if (firstMismatch < 0) firstMismatch = i;
  }
  final pixel = firstMismatch < 0 ? -1 : firstMismatch ~/ 4;
  final location = width == null || pixel < 0
      ? ''
      : ' at pixel (${pixel % width}, ${pixel ~/ width})';
  expect(
    mismatches,
    0,
    reason: '$path differs from the canonical render at byte '
        '$firstMismatch$location: actual '
        '${firstMismatch < 0 ? '' : actual.sublist(firstMismatch, math.min(actual.length, firstMismatch + 4))}, '
        'expected '
        '${firstMismatch < 0 ? '' : expected.sublist(firstMismatch, math.min(expected.length, firstMismatch + 4))}',
  );
}

void _expectExactImagePixels(
    img.Image actual, img.Image expected, String path) {
  _expectExactPixels(
    actual.getBytes(order: img.ChannelOrder.rgba),
    expected.getBytes(order: img.ChannelOrder.rgba),
    path,
  );
}

String _read(String path) => File(path).readAsStringSync();

String _androidColor(String name, String qualifier) {
  final source = _read('android/app/src/main/res/values$qualifier/colors.xml');
  return RegExp('<color name="$name">([^<]+)</color>')
      .firstMatch(source)!
      .group(1)!
      .trim()
      .toUpperCase();
}

List<int> _storyboardColor(String attributes) {
  double component(String name) => double.parse(
      RegExp('$name="([0-9.]+)"').firstMatch(attributes)!.group(1)!);
  return [
    (component('red') * 255).round(),
    (component('green') * 255).round(),
    (component('blue') * 255).round(),
  ];
}

Future<ui.Image> _decode(String path) async {
  final codec = await ui.instantiateImageCodec(File(path).readAsBytesSync());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

Future<Uint8List> _rgba(ui.Image image) async =>
    (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();

bool _hasGold(Uint8List pixels) {
  for (var i = 0; i < pixels.length; i += 4) {
    final r = pixels[i];
    final g = pixels[i + 1];
    final b = pixels[i + 2];
    if (pixels[i + 3] > 0 && r > 150 && g > 100 && b < 150) return true;
  }
  return false;
}

bool _isBackgroundPixel(Uint8List pixels, int x, int y, int width) {
  final i = (y * width + x) * 4;
  return pixels[i] == 11 &&
      pixels[i + 1] == 13 &&
      pixels[i + 2] == 16 &&
      pixels[i + 3] == 255;
}
