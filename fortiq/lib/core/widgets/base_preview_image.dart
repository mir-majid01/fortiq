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
    this.thumbnailUrl,
    this.localImagePath,
    this.onRetry,
    this.retryKey = 0,
    this.useFullSize = false,
  });

  final String? imageUrl;

  /// Lightweight variant of [imageUrl] used by grid cards.
  final String? thumbnailUrl;
  final String? localImagePath;
  final VoidCallback? onRetry;
  final int retryKey;

  /// Loads [imageUrl] instead of the lighter [thumbnailUrl].
  final bool useFullSize;

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
    final thumbnail = thumbnailUrl?.trim();
    final full = imageUrl?.trim();
    final url = (!useFullSize && thumbnail != null && thumbnail.isNotEmpty)
        ? thumbnail
        : full;
    if (url == null || url.isEmpty) {
      return const FortiqPreviewError(
        message: 'No cleared preview is available.',
        showRetry: false,
      );
    }
    final usingThumbnail = !useFullSize &&
        thumbnail != null &&
        thumbnail.isNotEmpty &&
        thumbnail != full;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decode at the size the preview is actually painted at. Decoding a
        // 1600px source into a 170px card is the slowest part of showing a
        // catalogue preview, so the decode width follows the layout box.
        final pixelRatio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
        final width = constraints.maxWidth;
        final decodeWidth = width.isFinite && width > 0
            ? (width * pixelRatio).ceil().clamp(240, 1600)
            : null;
        return CachedNetworkImage(
          imageUrl: url,
          cacheKey: '$url#$retryKey',
          fit: BoxFit.cover,
          memCacheWidth: decodeWidth,
          fadeInDuration: Duration.zero,
          progressIndicatorBuilder: (context, url, progress) =>
                FortiqPreviewPlaceholder(
              progress: progress.totalSize == null ? null : progress.progress,
            ),
          errorWidget: (context, url, error) {
            // A thumbnail can fail while the full preview is still reachable
            // (a resized rendition was removed upstream, a proxy is down).
            // Fall back to the original instead of showing a dead card.
            if (usingThumbnail && full != null && full.isNotEmpty) {
              return CachedNetworkImage(
                imageUrl: full,
                cacheKey: '$full#$retryKey',
                fit: BoxFit.cover,
                memCacheWidth: decodeWidth,
                fadeInDuration: Duration.zero,
                progressIndicatorBuilder: (context, url, progress) =>
                    FortiqPreviewPlaceholder(
                  progress: progress.totalSize == null ? null : progress.progress,
                ),
                errorWidget: (context, url, error) =>
                    FortiqPreviewError(onRetry: onRetry),
              );
            }
            return FortiqPreviewError(onRetry: onRetry);
          },
        );
      },
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
