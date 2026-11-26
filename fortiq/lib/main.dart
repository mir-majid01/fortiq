import 'package:flutter/widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

import 'app/app.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: binding);
  await initializeFortiq();
  runApp(const FortiqLaunch(
    onFirstFrame: FlutterNativeSplash.remove,
    child: FortiqApp(),
  ));
}

/// Startup work that must finish before the first branded Flutter frame.
/// The root remains the sole owner of catalogue loading and session state.
Future<void> initializeFortiq() async {
  SystemChrome.setSystemUIOverlayStyle(fortiqSystemUi);
  const fonts = <String, List<String>>{
    'Manrope': [
      'assets/fonts/Manrope-500.ttf',
      'assets/fonts/Manrope-600.ttf',
      'assets/fonts/Manrope-700.ttf',
      'assets/fonts/Manrope-800.ttf',
    ],
    'Inter': [
      'assets/fonts/Inter-400.ttf',
      'assets/fonts/Inter-500.ttf',
      'assets/fonts/Inter-600.ttf',
      'assets/fonts/Inter-700.ttf',
    ],
  };
  await Future.wait([
    for (final entry in fonts.entries)
      () async {
        final loader = FontLoader(entry.key);
        for (final path in entry.value) {
          loader.addFont(rootBundle.load(path));
        }
        await loader.load();
      }(),
  ]);
}

/// Releases the native splash only after [child] has completed its first
/// frame. Registration happens once, so later rebuilds cannot release twice.
class FortiqLaunch extends StatefulWidget {
  const FortiqLaunch({
    super.key,
    required this.child,
    required this.onFirstFrame,
  });

  final Widget child;
  final VoidCallback onFirstFrame;

  @override
  State<FortiqLaunch> createState() => _FortiqLaunchState();
}

class _FortiqLaunchState extends State<FortiqLaunch> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onFirstFrame();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
