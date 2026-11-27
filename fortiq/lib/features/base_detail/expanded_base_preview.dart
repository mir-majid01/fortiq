import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/icons/fortiq_icons.dart';
import '../../core/widgets/buttons.dart';
import '../base_preview/base_preview.dart';
import '../base_preview/layout_preview.dart';
import '../../data/models/base_layout.dart';

/// Full-screen, pinch-zoomable base preview opened from Base Detail.
class ExpandedBasePreview extends StatefulWidget {
  const ExpandedBasePreview({
    super.key,
    required this.seed,
    this.title,
    this.base,
  });

  final int seed;
  final String? title;
  final BaseLayout? base;

  static Route<void> route({
    required int seed,
    String? title,
    BaseLayout? base,
  }) =>
      PageRouteBuilder(
        opaque: false,
        transitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (_, animation, __) => FadeTransition(
          opacity: animation,
          child: ExpandedBasePreview(seed: seed, title: title, base: base),
        ),
      );

  @override
  State<ExpandedBasePreview> createState() => _ExpandedBasePreviewState();
}

class _ExpandedBasePreviewState extends State<ExpandedBasePreview>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late final AnimationController _zoomController;
  late Animation<Matrix4> _zoomAnimation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _zoomAnimation = Matrix4Tween(
      begin: Matrix4.identity(),
      end: Matrix4.identity(),
    ).animate(_zoomController);
    _zoomController.addListener(() {
      _controller.value = _zoomAnimation.value;
    });
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _animateTransform(Matrix4 target) {
    if (MediaQuery.disableAnimationsOf(context)) {
      _zoomController.stop();
      _controller.value = target;
      return;
    }
    _zoomAnimation = Matrix4Tween(
      begin: _controller.value,
      end: target,
    ).animate(_zoomController.drive(CurveTween(curve: Curves.easeOut)));
    _zoomController.forward(from: 0);
  }

  void _handleDoubleTapDown(TapDownDetails details) =>
      _doubleTapDetails = details;

  void _handleDoubleTap() {
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    if (_controller.value != Matrix4.identity()) {
      _animateTransform(Matrix4.identity());
    } else {
      _animateTransform(
        Matrix4.identity()
          ..translateByDouble(-position.dx * 1.5, -position.dy * 1.5, 0, 1)
          ..scaleByDouble(2.5, 2.5, 2.5, 1),
      );
    }
  }

  void _zoomIn() {
    final currentScale = _controller.value.getMaxScaleOnAxis();
    final nextScale = (currentScale * 1.5).clamp(1.5, 5.0);
    if (nextScale == currentScale) return;
    final center = MediaQuery.sizeOf(context).center(Offset.zero);
    _animateTransform(
      Matrix4.identity()
        ..translateByDouble(
          center.dx * (1 - nextScale),
          center.dy * (1 - nextScale),
          0,
          1,
        )
        ..scaleByDouble(nextScale, nextScale, nextScale, 1),
    );
  }

  void _resetZoom() => _animateTransform(Matrix4.identity());

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            // Square preview, centred, pinch/double-tap zoom.
            Center(
              child: InteractiveViewer(
                transformationController: _controller,
                minScale: 1.0,
                maxScale: 5.0,
                child: GestureDetector(
                  onDoubleTapDown: _handleDoubleTapDown,
                  onDoubleTap: _handleDoubleTap,
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: widget.base == null
                          ? BasePreview(seed: widget.seed)
                          : LayoutPreview(base: widget.base!),
                    ),
                  ),
                ),
              ),
            ),
            // Title + hint at the bottom.
            Positioned(
              left: 20,
              right: 20,
              bottom: 0,
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (widget.title != null)
                      Text(
                        widget.title!,
                        style:
                            AppTypography.sectionTitle.copyWith(fontSize: 18),
                      ),
                    const SizedBox(height: 6),
                    Text(
                      'Pinch or double-tap to zoom',
                      style: AppTypography.cardSubtitle,
                    ),
                  ],
                ),
              ),
            ),
            // Close (top-left) + reset zoom (top-right).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Row(
                    children: [
                      OverlayIconButton(
                        label: 'Close expanded preview',
                        size: 40,
                        color: AppColors.controlBackdrop,
                        onTap: () => Navigator.of(context).pop(),
                        child: FortiqIcon(FortiqIcons.close,
                            size: 18, color: AppColors.textPrimary),
                      ),
                      const Spacer(),
                      Semantics(
                        key: const Key('preview-zoom-in'),
                        container: true,
                        excludeSemantics: true,
                        button: true,
                        label: 'Zoom in',
                        child: OverlayIconButton(
                          label: 'Zoom in',
                          size: 40,
                          color: AppColors.controlBackdrop,
                          onTap: _zoomIn,
                          child: FortiqIcon(FortiqIcons.plus,
                              size: 18, color: AppColors.textPrimary),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Semantics(
                        key: const Key('preview-reset'),
                        container: true,
                        excludeSemantics: true,
                        button: true,
                        label: 'Reset zoom',
                        child: OverlayIconButton(
                          label: 'Reset zoom',
                          size: 40,
                          color: AppColors.controlBackdrop,
                          onTap: _resetZoom,
                          child: FortiqIcon(FortiqIcons.expand,
                              size: 16, color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
