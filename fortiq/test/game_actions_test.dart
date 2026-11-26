import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fortiq/app/theme/app_theme.dart';
import 'package:fortiq/core/widgets/game_actions.dart';
import 'package:fortiq/data/models/base_layout.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');
const _launchChannel = MethodChannel('plugins.flutter.io/url_launcher');
const _invokerKey = Key('game-action-invoker');
const _unavailableResult = 'dev.fluttercommunity.plus/share/unavailable';
const _launchError =
    'Could not open Clash of Clans — the game may not be installed.';
const _shareError = 'Sharing is unavailable on this device.';

const _gameLink = 'https://link.clashofclans.com/en?id=fortiq-layout';
const _linkedBase = BaseLayout(
  id: 'linked-base',
  name: 'Linked Base',
  village: Village.home,
  hallLevel: 17,
  categories: ['War'],
  layoutStyle: 'Hybrid',
  previewSeed: 5,
  creator: Creator(name: 'Builder'),
  isSample: false,
  gameLink: _gameLink,
);
const _sampleBase = BaseLayout(
  id: 'sample-base',
  name: 'Sample Base',
  village: Village.home,
  hallLevel: 17,
  categories: ['War'],
  layoutStyle: 'Hybrid',
  previewSeed: 5,
  creator: Creator(name: 'Builder'),
  isSample: true,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_shareChannel, null);
    messenger.setMockMethodCallHandler(_launchChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(_shareChannel, null);
    messenger.setMockMethodCallHandler(_launchChannel, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('shareBase', () {
    testWidgets('shares linked text from the invoking render box',
        (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (call) async {
        calls.add(call);
        return 'com.example.share-target';
      });
      final context = await _pumpInvoker(tester);
      final origin = tester.getRect(find.byKey(_invokerKey));

      await GameActions.shareBase(context, _linkedBase);
      await tester.pump();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'share');
      final arguments = Map<String, dynamic>.from(
        calls.single.arguments as Map,
      );
      expect(
        arguments['text'],
        'Linked Base — Clash of Clans base layout\n$_gameLink',
      );
      expect(arguments['originX'], origin.left);
      expect(arguments['originY'], origin.top);
      expect(arguments['originWidth'], origin.width);
      expect(arguments['originHeight'], origin.height);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('dismissed share does not show an error', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (call) async => '');
      final context = await _pumpInvoker(tester);

      await GameActions.shareBase(context, _linkedBase);
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('unavailable share shows the honest snackbar', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        _shareChannel,
        (call) async => _unavailableResult,
      );
      final context = await _pumpInvoker(tester);

      await GameActions.shareBase(context, _linkedBase);
      await tester.pumpAndSettle();

      expect(find.text(_shareError), findsOneWidget);
    });

    testWidgets('failed share shows the honest snackbar', (tester) async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (call) async {
        throw PlatformException(code: 'share_failed');
      });
      final context = await _pumpInvoker(tester);

      await GameActions.shareBase(context, _linkedBase);
      await tester.pumpAndSettle();

      expect(find.text(_shareError), findsOneWidget);
    });

    testWidgets('sample base is shared without inventing a game link',
        (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (call) async {
        calls.add(call);
        return 'com.example.share-target';
      });
      final context = await _pumpInvoker(tester);

      await GameActions.shareBase(context, _sampleBase);
      await tester.pump();

      final arguments = Map<String, dynamic>.from(
        calls.single.arguments as Map,
      );
      expect(
        arguments['text'],
        'Sample Base — Clash of Clans base layout shared from Fortiq',
      );
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('unmounted invoker ignores a failed pending share',
        (tester) async {
      final response = Completer<String>();
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (call) {
        calls.add(call);
        return response.future;
      });
      final context = await _pumpInvoker(tester);

      final action = GameActions.shareBase(context, _linkedBase);
      final completion = expectLater(action, completes);
      await tester.pump();
      expect(calls, hasLength(1));

      await tester.pumpWidget(const SizedBox.shrink());
      response.completeError(PlatformException(code: 'share_failed'));
      await tester.pump();
      await completion;

      expect(tester.takeException(), isNull);
    });

    testWidgets('unmounted invoker ignores an unavailable pending share',
        (tester) async {
      final response = Completer<String>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_shareChannel, (call) => response.future);
      final context = await _pumpInvoker(tester);

      final action = GameActions.shareBase(context, _linkedBase);
      final completion = expectLater(action, completes);
      await tester.pumpWidget(const SizedBox.shrink());
      response.complete(_unavailableResult);
      await tester.pump();
      await completion;

      expect(tester.takeException(), isNull);
    });
  });

  group('openInGame', () {
    testWidgets('launches the real link in external application mode',
        (tester) async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(_launchChannel, (call) async {
        calls.add(call);
        return true;
      });
      final context = await _pumpInvoker(tester);

      await GameActions.openInGame(context, _linkedBase);
      await tester.pump();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'launch');
      final arguments = Map<String, dynamic>.from(
        calls.single.arguments as Map,
      );
      expect(arguments['url'], _gameLink);
      expect(arguments['useSafariVC'], isFalse);
      expect(arguments['useWebView'], isFalse);
      expect(arguments['universalLinksOnly'], isFalse);
      expect(find.byType(SnackBar), findsNothing);
    });

    for (final throws in [false, true]) {
      testWidgets(
          'launch that ${throws ? 'throws' : 'returns false'} shows the existing error',
          (tester) async {
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_launchChannel, (call) async {
          if (throws) {
            throw PlatformException(code: 'launch_failed');
          }
          return false;
        });
        final context = await _pumpInvoker(tester);

        await GameActions.openInGame(context, _linkedBase);
        await tester.pumpAndSettle();

        expect(find.text(_launchError), findsOneWidget);
      });

      testWidgets(
          'unmounted invoker ignores a pending launch that '
          '${throws ? 'throws' : 'returns false'}', (tester) async {
        final response = Completer<bool>();
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_launchChannel, (call) {
          calls.add(call);
          return response.future;
        });
        final context = await _pumpInvoker(tester);

        final action = GameActions.openInGame(context, _linkedBase);
        final completion = expectLater(action, completes);
        await tester.pump();
        expect(calls, hasLength(1));

        await tester.pumpWidget(const SizedBox.shrink());
        if (throws) {
          response.completeError(PlatformException(code: 'launch_failed'));
        } else {
          response.complete(false);
        }
        await tester.pump();
        await completion;

        expect(tester.takeException(), isNull);
      });
    }
  });

  testWidgets('copyLink copies the real link and confirms only that action',
      (tester) async {
    String? clipboardText;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardText = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    final context = await _pumpInvoker(tester);

    await GameActions.copyLink(context, _linkedBase);
    await tester.pumpAndSettle();

    expect(clipboardText, _gameLink);
    expect(find.text('Base link copied to clipboard'), findsOneWidget);
  });

  final missingLinkActions =
      <String, Future<void> Function(BuildContext, BaseLayout)>{
    'openInGame': GameActions.openInGame,
    'copyLink': GameActions.copyLink,
  };
  for (final action in missingLinkActions.entries) {
    testWidgets('${action.key} offers a working honest sample-link fallback',
        (tester) async {
      var shareCalls = 0;
      var launchCalls = 0;
      var clipboardCalls = 0;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(_shareChannel, (call) async {
        shareCalls++;
        return 'com.example.share-target';
      });
      messenger.setMockMethodCallHandler(_launchChannel, (call) async {
        launchCalls++;
        return true;
      });
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboardCalls++;
        }
        return null;
      });
      final context = await _pumpInvoker(tester);

      final pending = action.value(context, _sampleBase);
      await tester.pumpAndSettle();

      expect(find.text('Open in Game'), findsOneWidget);
      expect(
        find.textContaining('placeholder base from the design sample'),
        findsOneWidget,
      );
      expect(find.text('Got it'), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
      expect(shareCalls, 0);
      expect(launchCalls, 0);
      expect(clipboardCalls, 0);

      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      await pending;

      expect(find.text('Open in Game'), findsNothing);
    });
  }
}

Future<BuildContext> _pumpInvoker(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: buildFortiqTheme(),
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.fromLTRB(17, 23, 0, 0),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              key: _invokerKey,
              width: 120,
              height: 44,
              child: const Text('Action host'),
            ),
          ),
        ),
      ),
    ),
  );
  return tester.element(find.byKey(_invokerKey));
}
