import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../data/models/base_layout.dart';
import '../icons/fortiq_icons.dart';
import 'buttons.dart';

/// Integrations around the official Clash of Clans layout deep link
/// (`https://link.clashofclans.com/...`).
///
/// The community catalogue ships real links, so in real-catalogue mode
/// "Open in Game" opens the game directly. Sample bases have no link — the
/// actions surface an honest fallback instead of pretending to succeed.
abstract final class GameActions {
  static Future<void> openInGame(BuildContext context, BaseLayout base) async {
    final link = base.gameLink;
    if (link == null) {
      await _showLinkFallback(context, base);
      return;
    }
    var launched = false;
    try {
      launched = await launchUrl(
        Uri.parse(link),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      _showLaunchRecovery(context, base);
    }
  }

  static Future<void> copyLink(BuildContext context, BaseLayout base) async {
    final link = base.gameLink;
    if (link == null) {
      await _showLinkFallback(context, base);
      return;
    }
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(_snack('Base link copied to clipboard'));
    }
  }

  static Future<void> shareBase(BuildContext context, BaseLayout base) async {
    final link = base.gameLink;
    final text = link != null
        ? '${base.name} — Clash of Clans base layout\n$link'
        : '${base.name} — Clash of Clans base layout shared from Fortiq';
    final renderObject = context.findRenderObject();
    final origin = renderObject is RenderBox
        ? renderObject.localToGlobal(Offset.zero) & renderObject.size
        : null;
    try {
      final result = await Share.share(text, sharePositionOrigin: origin);
      if (result.status == ShareResultStatus.unavailable && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snack('Sharing is unavailable on this device.'),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          _snack('Sharing is unavailable on this device.'),
        );
      }
    }
  }

  static SnackBar _snack(String message) => SnackBar(content: Text(message));

  static Future<void> _showLaunchRecovery(
    BuildContext context,
    BaseLayout base,
  ) {
    final link = base.gameLink!;
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      barrierColor: AppColors.scrim.withValues(alpha: 0.86),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Could not open Clash of Clans',
                  style: AppTypography.filtersTitle),
              const SizedBox(height: 8),
              Text(
                'The game may not be installed. You can open the official layout link in a browser, copy it, or get the game from Supercell.',
                style: AppTypography.verifiedLine.copyWith(height: 1.5),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Open in browser',
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await launchUrl(
                      Uri.parse(link),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: link));
                    if (sheetContext.mounted) {
                      Navigator.of(sheetContext).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                          _snack('Base link copied to clipboard'));
                    }
                  },
                  child: const Text('Copy link'),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await launchUrl(
                      Uri.parse('https://supercell.com/en/games/clashofclans/'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: const Text('Get Clash of Clans'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _showLinkFallback(BuildContext context, BaseLayout base) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      barrierColor: AppColors.scrim.withValues(alpha: 0.86),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Open in Game', style: AppTypography.filtersTitle),
              const SizedBox(height: 10),
              Text(
                base.isSample
                    ? 'This is a placeholder base from the design sample and has no in-game layout link yet. Real catalogue entries include official link.clashofclans.com deep links.'
                    : 'No in-game layout link is available for this base right now.',
                style: AppTypography.verifiedLine.copyWith(height: 1.5),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Notification bell → branded "all caught up" sheet (no backend exists yet;
/// the integration point is isolated here).
Future<void> showNotificationsSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.surface,
    barrierColor: AppColors.scrim.withValues(alpha: 0.86),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.chipInactive,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            FortiqIcon(FortiqIcons.bell, size: 26, color: AppColors.gold),
            const SizedBox(height: 12),
            Text("You're all caught up", style: AppTypography.screenTitle),
            const SizedBox(height: 6),
            Text(
              'Fresh drops and creator activity will land here.',
              style: AppTypography.cardSubtitle,
            ),
          ],
        ),
      ),
    ),
  );
}
