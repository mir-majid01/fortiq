import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_typography.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/state_scope.dart';

class ImportBaseSheet extends StatefulWidget {
  const ImportBaseSheet({super.key, this.previewFile});

  final File? previewFile;

  @override
  State<ImportBaseSheet> createState() => _ImportBaseSheetState();
}

class _ImportBaseSheetState extends State<ImportBaseSheet> {
  final _link = TextEditingController();
  final _name = TextEditingController();
  final _credit = TextEditingController();
  File? _preview;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _preview = widget.previewFile;
  }

  @override
  void dispose() {
    _link.dispose();
    _name.dispose();
    _credit.dispose();
    super.dispose();
  }

  Future<void> _choosePreview() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (!mounted || picked == null) return;
      setState(() {
        _preview = File(picked.path);
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not open the image picker. Try again.');
      }
    }
  }

  Future<void> _save() async {
    final preview = _preview;
    if (preview == null) {
      setState(() =>
          _error = 'Choose a preview image you own or have permission to use.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await StateScope.of(context).importBase(
        link: _link.text,
        name: _name.text,
        attribution: _credit.text,
        preview: preview,
      );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error is FormatException
            ? error.message
            : 'Could not import this base. Check the link and try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.borderStrong)),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.chipInactive,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Import a base', style: AppTypography.filtersTitle),
              const SizedBox(height: 6),
              Text(
                'Paste an official Clash of Clans OpenLayout link and choose your own preview. Fortiq does not scrape third-party catalogues. The game remains the authority on whether the link imports successfully.',
                style: AppTypography.verifiedLine.copyWith(height: 1.5),
              ),
              const SizedBox(height: 16),
              _Field(
                key: const Key('import-link'),
                controller: _link,
                label: 'Official layout link',
                hint: 'https://link.clashofclans.com/…',
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 12),
              _Field(
                key: const Key('import-name'),
                controller: _name,
                label: 'Base name',
                hint: 'My imported base',
              ),
              const SizedBox(height: 12),
              _Field(
                key: const Key('import-attribution'),
                controller: _credit,
                label: 'Credit (optional)',
                hint: 'Your name or source credit',
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _choosePreview,
                icon: const Icon(Icons.image_outlined),
                label: Text(
                    _preview == null ? 'Choose preview' : 'Change preview'),
              ),
              if (_preview != null) ...[
                const SizedBox(height: 10),
                Semantics(
                  label: 'Selected preview: ${_preview!.path}',
                  child: const SizedBox(
                    height: 44,
                    child: ColoredBox(
                      color: AppColors.card,
                      child: Center(child: Text('Preview selected')),
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Semantics(
                  liveRegion: true,
                  child: Text(_error!,
                      style: AppTypography.cardSubtitle
                          .copyWith(color: AppColors.error)),
                ),
              ],
              const SizedBox(height: 18),
              PrimaryButton(
                label: _saving ? 'Importing…' : 'Import base',
                onTap: _saving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: keyboardType,
      style: AppTypography.cardTitle,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.borderStrong),
        ),
      ),
    );
  }
}
