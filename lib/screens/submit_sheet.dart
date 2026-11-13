import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Community submission form. Frontend only: nothing is sent anywhere yet.
Future<void> showSubmitSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (context) => const _SubmitSheet(),
  );
}

class _SubmitSheet extends StatefulWidget {
  const _SubmitSheet();

  @override
  State<_SubmitSheet> createState() => _SubmitSheetState();
}

class _SubmitSheetState extends State<_SubmitSheet> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _sequence = TextEditingController();
  final _notes = TextEditingController();
  GamePlatform _platform = GamePlatform.ps5;
  CheatCategory _category = CheatCategory.vehicles;

  @override
  void dispose() {
    _title.dispose();
    _sequence.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_form.currentState?.validate() ?? false)) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(content: Text('Thanks! It will show as Unverified until it’s tested.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + bottomInset),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Submit a cheat', style: AppText.cardTitle(context)),
              const SizedBox(height: 4),
              Text('New entries start as Unverified until someone tests them in the game.',
                  style: AppText.caption(context)),
              const SizedBox(height: 18),
              _Field(
                label: 'What does it do?',
                controller: _title,
                hint: 'e.g. Spawn helicopter',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Add a short name' : null,
              ),
              const SizedBox(height: 14),
              Text('Platform', style: AppText.caption(context)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final p in GamePlatform.values)
                    ChoiceChip(
                      label: Text(p.short),
                      selected: p == _platform,
                      onSelected: (_) => setState(() => _platform = p),
                      selectedColor: AppColors.text,
                      showCheckmark: false,
                      labelStyle: AppText.label(context).copyWith(color: p == _platform ? AppColors.dark : AppColors.muted),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Text('Category', style: AppText.caption(context)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in CheatCategory.values.where((c) => c != CheatCategory.all))
                    ChoiceChip(
                      label: Text(c.label),
                      selected: c == _category,
                      onSelected: (_) => setState(() => _category = c),
                      selectedColor: AppColors.text,
                      showCheckmark: false,
                      labelStyle: AppText.label(context).copyWith(color: c == _category ? AppColors.dark : AppColors.muted),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              _Field(
                label: 'Button sequence',
                controller: _sequence,
                hint: 'Buttons separated by spaces',
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Add the sequence' : null,
              ),
              const SizedBox(height: 14),
              _Field(label: 'Notes (optional)', controller: _notes, hint: 'Where and how you tested it', maxLines: 3),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _submit,
                child: const Text('Submit for testing'),
              ),
              const SizedBox(height: 12),
              Text(kDisclaimer, textAlign: TextAlign.center, style: AppText.small(context).copyWith(color: AppColors.muted, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.validator,
    this.maxLines = 1,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final FormFieldValidator<String>? validator;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(maxLines > 1 ? 18 : 999),
      borderSide: const BorderSide(color: AppColors.stroke),
    );
    return TextFormField(
      controller: controller,
      validator: validator,
      maxLines: maxLines,
      cursorColor: AppColors.accent,
      style: AppText.body(context),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.glass,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.accent)),
        errorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: border.copyWith(borderSide: const BorderSide(color: AppColors.error)),
      ),
    );
  }
}
