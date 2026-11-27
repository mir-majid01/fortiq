import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/icons/fortiq_icons.dart';
import '../../core/widgets/buttons.dart';
import 'controllers/update_controller.dart';
import 'models/update_info.dart';

class UpdateScreen extends StatelessWidget {
  const UpdateScreen({super.key, required this.controller});

  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          title: Text('App updates', style: AppTypography.screenTitle),
          leading: IconButton(
            tooltip: 'Back',
            onPressed: () => Navigator.of(context).pop(),
            icon: const FortiqIcon(FortiqIcons.chevronLeft,
                size: 20, color: AppColors.textPrimary),
          ),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _CurrentVersionCard(controller: controller),
              const SizedBox(height: 16),
              _StatusCard(controller: controller),
              if (controller.latestUpdate case final update?) ...[
                const SizedBox(height: 16),
                _ReleaseCard(update: update),
                const SizedBox(height: 16),
                Card(
                  color: AppColors.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Patch notes', style: AppTypography.sectionTitle),
                        const SizedBox(height: 12),
                        MarkdownBody(
                          data: update.notes.trim().isEmpty
                              ? 'No patch notes were provided.'
                              : update.notes,
                          styleSheet: MarkdownStyleSheet(
                            p: AppTypography.cardSubtitle.copyWith(height: 1.5),
                            h1: AppTypography.sectionTitle,
                            h2: AppTypography.sectionTitle,
                            h3: AppTypography.cardTitle,
                            listBullet: AppTypography.cardSubtitle,
                            code: AppTypography.statLabel,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              _Actions(controller: controller),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentVersionCard extends StatelessWidget {
  const _CurrentVersionCard({required this.controller});

  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    final version = controller.installedVersion ?? 'Unknown';
    final build = controller.installedBuild;
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            FortiqIcon(FortiqIcons.update, size: 24, color: AppColors.gold),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Installed version', style: AppTypography.statLabel),
                  const SizedBox(height: 4),
                  Text('Fortiq $version${build == null ? '' : ' ($build)'}',
                      style: AppTypography.cardTitle),
                  if (controller.lastChecked case final checked?) ...[
                    const SizedBox(height: 4),
                    Text('Last checked ${_date(checked)}',
                        style: AppTypography.cardTime),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.controller});

  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    final progress = controller.progress;
    return Card(
      color: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_title(controller.status), style: AppTypography.sectionTitle),
            const SizedBox(height: 6),
            Text(_message(controller.status, controller.supportsApk),
                style: AppTypography.cardSubtitle.copyWith(height: 1.5)),
            if (controller.status == UpdateStatus.downloading ||
                controller.status == UpdateStatus.verifying) ...[
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: controller.status == UpdateStatus.verifying
                      ? null
                      : progress?.fraction,
                  minHeight: 6,
                  color: AppColors.gold,
                  backgroundColor: AppColors.border,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                progress == null
                    ? 'Preparing download…'
                    : '${_bytes(progress.receivedBytes)} / '
                        '${_bytes(progress.totalBytes)} · '
                        '${_speed(progress.bytesPerSecond)}'
                        '${progress.eta == null ? '' : ' · ETA ${_duration(progress.eta!)}'}',
                style: AppTypography.statLabel,
              ),
            ],
            if (controller.error case final error?) ...[
              const SizedBox(height: 10),
              Text(error.message,
                  style: AppTypography.cardSubtitle
                      .copyWith(color: AppColors.error)),
            ],
          ],
        ),
      ),
    );
  }

  static String _title(UpdateStatus status) => switch (status) {
        UpdateStatus.idle => 'Ready to check',
        UpdateStatus.checking => 'Checking for updates',
        UpdateStatus.upToDate => 'You’re up to date',
        UpdateStatus.available => 'Update available',
        UpdateStatus.downloading => 'Downloading update',
        UpdateStatus.verifying => 'Verifying checksum',
        UpdateStatus.ready => 'Ready to install',
        UpdateStatus.handingOff => 'Opening installer',
        UpdateStatus.handedOff => 'Installer opened',
        UpdateStatus.error => 'Update needs attention',
      };

  static String _message(UpdateStatus status, bool supportsApk) =>
      switch (status) {
        UpdateStatus.idle =>
          'Check GitHub for the latest stable Fortiq release.',
        UpdateStatus.checking => 'Contacting GitHub Releases…',
        UpdateStatus.upToDate => 'No newer stable release is available.',
        UpdateStatus.available =>
          'A newer verified release is ready to download.',
        UpdateStatus.downloading =>
          'Download speed and remaining time are shown below.',
        UpdateStatus.verifying =>
          'Checking byte count and SHA-256 before install.',
        UpdateStatus.ready =>
          'The APK passed byte-count and checksum verification.',
        UpdateStatus.handingOff =>
          'Handing the verified APK to Android’s installer.',
        UpdateStatus.handedOff =>
          'Fortiq does not detect installation completion. Finish in the system installer.',
        UpdateStatus.error => supportsApk
            ? 'Use Retry or open the release page for recovery.'
            : 'Updates are managed by the App Store on iOS.',
      };
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.update});

  final UpdateInfo update;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Latest release', style: AppTypography.statLabel),
            const SizedBox(height: 4),
            Text('Fortiq ${update.versionName}',
                style: AppTypography.cardTitle),
            const SizedBox(height: 8),
            _Detail(label: 'Published', value: _date(update.publishedAt)),
            _Detail(label: 'APK size', value: _bytes(update.apkSize)),
            _Detail(label: 'Asset', value: update.apkName),
            _Detail(
              label: 'SHA-256',
              value: update.apkSha256.isEmpty
                  ? 'Required checksum asset will be fetched before install'
                  : update.apkSha256,
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 76, child: Text(label, style: AppTypography.statLabel)),
          Expanded(child: Text(value, style: AppTypography.cardSubtitle)),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.controller});

  final UpdateController controller;

  @override
  Widget build(BuildContext context) {
    final latest = controller.latestUpdate;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.status == UpdateStatus.downloading)
          GhostButton(
            label: 'Cancel download',
            onTap: controller.cancelDownload,
          )
        else if (controller.status == UpdateStatus.ready)
          PrimaryButton(
            label: 'Install update',
            onTap: controller.installUpdate,
          )
        else if (controller.canDownload)
          PrimaryButton(
            label: 'Download update',
            onTap: controller.downloadUpdate,
          )
        else
          PrimaryButton(
            label: controller.status == UpdateStatus.checking
                ? 'Checking…'
                : 'Check for updates',
            onTap: controller.status == UpdateStatus.checking
                ? null
                : controller.refresh,
          ),
        if (controller.status == UpdateStatus.error) ...[
          const SizedBox(height: 8),
          GhostButton(label: 'Retry', onTap: controller.retry),
        ],
        if (latest != null) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _open(context, latest.releaseUrl),
            child: const Text('Open release page'),
          ),
          TextButton(
            onPressed: () => _copy(context, latest.releaseUrl),
            child: const Text('Copy release link'),
          ),
        ],
      ],
    );
  }

  static Future<void> _open(BuildContext context, String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the release page.')),
        );
      }
    }
  }

  static Future<void> _copy(BuildContext context, String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Release link copied to clipboard')),
      );
    }
  }
}

String _date(DateTime? value) => value == null
    ? 'Not provided'
    : '${value.year}-${_two(value.month)}-${_two(value.day)}';
String _two(int value) => value.toString().padLeft(2, '0');
String _bytes(int value) => value >= 1024 * 1024
    ? '${(value / (1024 * 1024)).toStringAsFixed(1)} MB'
    : '${(value / 1024).toStringAsFixed(1)} KB';
String _speed(double value) => value >= 1024 * 1024
    ? '${(value / (1024 * 1024)).toStringAsFixed(1)} MB/s'
    : '${(value / 1024).toStringAsFixed(1)} KB/s';
String _duration(Duration value) {
  if (value.inSeconds < 60) return '${value.inSeconds}s';
  return '${value.inMinutes}m ${value.inSeconds % 60}s';
}
