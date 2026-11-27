import 'package:flutter/material.dart';

import '../../core/widgets/base_preview_image.dart';
import '../../data/models/base_layout.dart';
import 'base_preview.dart';

class LayoutPreview extends StatefulWidget {
  const LayoutPreview({super.key, required this.base});

  final BaseLayout base;

  @override
  State<LayoutPreview> createState() => _LayoutPreviewState();
}

class _LayoutPreviewState extends State<LayoutPreview> {
  int _retryKey = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.base.isSample) {
      return BasePreview(seed: widget.base.previewSeed);
    }
    return BasePreviewImage(
      imageUrl: widget.base.imageUrl,
      localImagePath: widget.base.localImagePath,
      retryKey: _retryKey,
      onRetry: () => setState(() => _retryKey++),
    );
  }
}
