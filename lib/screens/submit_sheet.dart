import 'package:flutter/material.dart';

import '../data/backend_client.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Community submission form.
///
/// Sends the cheat to the backend's moderation queue. Nothing submitted here
/// reaches other users until a moderator approves it, and approved entries
/// enter the content pack as Unverified, never Verified.
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
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _sequence.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    if (_sending) return;

    final app = AppScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // One glyph per button, as the detail screen's chips render them.
    final sequence = _sequence.text
        .trim()
        .split(RegExp(r'[\s,]+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);

    if (!app.hasBackend) {
      navigator.pop();
      messenger.showSnackBar(const SnackBar(
        content: Text('Submissions need a backend. This build has none configured.'),
      ));
      return;
    }

    setState(() => _sending = true);
    try {
      await app.submitCheat(
        title: _title.text,
        category: _category,
        sequence: sequence,
        sourceNote: _notes.text,
      );
      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(const SnackBar(
        content: Text('Thanks! It will show as Unverified until it’s tested.'),
      ));
    } on BackendException catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(const SnackBar(
        content: Text('Could not reach the server. Try again when you are online.'),
      ));
    }
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
                onPressed: _sending ? null : _submit,
                child: _sending
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit for testing'),
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
