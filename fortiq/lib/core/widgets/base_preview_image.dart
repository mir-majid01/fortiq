import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../icons/fortiq_icons.dart';

class BasePreviewImage extends StatelessWidget {
  const BasePreviewImage({
    super.key,
    this.imageUrl,
    this.localImagePath,
    this.onRetry,
    this.retryKey = 0,
  });

  final String? imageUrl;
  final String? localImagePath;
  final VoidCallback? onRetry;
  final int retryKey;

  @override
  Widget build(BuildContext context) {
    final localPath = localImagePath?.trim();
    if (localPath != null && localPath.isNotEmpty) {
      return Image.file(
        File(localPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stack) =>
            FortiqPreviewError(onRetry: onRetry),
      );
    }
    final url = imageUrl?.trim();
    if (url == null || url.isEmpty) {
      return const FortiqPreviewError(
        message: 'No cleared preview is available.',
        showRetry: false,
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: '$url#$retryKey',
      fit: BoxFit.cover,
      progressIndicatorBuilder: (context, url, progress) =>
          FortiqPreviewPlaceholder(
        progress: progress.totalSize == null ? null : progress.progress,
      ),
      errorWidget: (context, url, error) =>
          FortiqPreviewError(onRetry: onRetry),
    );
  }
}

class FortiqPreviewPlaceholder extends StatelessWidget {
  const FortiqPreviewPlaceholder({super.key, this.progress});

  final double? progress;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.card,
      child: Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 2,
            color: AppColors.gold,
            backgroundColor: AppColors.border,
          ),
        ),
      ),
    );
  }
}

class FortiqPreviewError extends StatelessWidget {
  const FortiqPreviewError({
    super.key,
    this.message = 'Preview could not be loaded.',
    this.onRetry,
    this.showRetry = true,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool showRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.card,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxHeight < 120 || constraints.maxWidth < 120) {
            return Semantics(
              label: 'Preview unavailable. $message',
              child: Center(
                child: FortiqIcon(FortiqIcons.expand,
                    size: 20, color: AppColors.textSecondary),
              ),
            );
          }
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FortiqIcon(FortiqIcons.expand,
                      size: 24, color: AppColors.textSecondary),
                  const SizedBox(height: 8),
                  Text(
                    'Preview unavailable',
                    style: AppTypography.sectionTitle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: AppTypography.cardSubtitle,
                    textAlign: TextAlign.center,
                  ),
                  if (showRetry && onRetry != null) ...[
                    const SizedBox(height: 8),
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
