import 'dart:async';

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/icons/fortiq_emblem.dart';

/// Splash: emblem + FORTIQ wordmark + tagline centred at the reference
/// position, gold loading bar near the bottom. Auto-advances after 2s.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.onDone});

  final VoidCallback? onDone;

  /// How long the splash is shown.
  static const Duration duration = Duration(milliseconds: 2000);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashScreen.duration, () => widget.onDone?.call());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reference: content column starts at 318px of 844 (~37.7% from top).
    // Proportional so it stays balanced on shorter and taller screens.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(builder: (context, constraints) {
        return Stack(
          children: [
            Positioned(
              top: constraints.maxHeight * 0.377,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  const FortiqEmblem(width: 92, height: 118),
                  const SizedBox(height: 28),
                  // Letter-spacing trails the last glyph; the matching
                  // left padding keeps the wordmark optically centred.
                  Padding(
                    padding: const EdgeInsets.only(left: 7.68), // .24em @ 32
                    child: Text('FORTIQ', style: AppTypography.brand(32)),
                  ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(left: 2.64), // .24em @ 11
                    child: Text('BUILD. DEFEND. DOMINATE.',
                        style: AppTypography.splashTagline),
                  ),
                ],
              ),
            ),
            // Loading bar: 96×2 track, 42% gold fill, 84px from the bottom.
            Positioned(
              left: 0,
              right: 0,
              bottom: 84,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(1),
                  child: Container(
                    width: 96,
                    height: 2,
                    color: const Color(0x14FFFFFF), // rgba(255,255,255,.08)
                    child: const FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: 0.42,
                      child: ColoredBox(color: AppColors.gold),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}
