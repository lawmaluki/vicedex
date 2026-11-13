import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'cheat_library_screen.dart' show verificationMeters;
import '../theme/phosphor.dart';

class CheatDetailScreen extends StatefulWidget {
  const CheatDetailScreen({super.key, required this.cheatId});
  final String cheatId;

  @override
  State<CheatDetailScreen> createState() => _CheatDetailScreenState();
}

class _CheatDetailScreenState extends State<CheatDetailScreen> {
  bool _copied = false;
  Timer? _copyTimer;

  @override
  void dispose() {
    _copyTimer?.cancel();
    super.dispose();
  }

  Future<void> _copy(Cheat cheat, GamePlatform platform) async {
    final seq = cheat.sequenceFor(platform);
    if (seq.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: '${cheat.title} (${platform.short}): ${seq.join(' ')}'));
    HapticFeedback.lightImpact();
    if (!mounted) return;
    setState(() => _copied = true);
    _copyTimer?.cancel();
    _copyTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final cheat = app.cheatById(widget.cheatId);
    final platform = app.platform;
    final seq = cheat.sequenceFor(platform);
    final fav = app.isFavourite(cheat.id);
    final vote = app.voteFor(cheat.id);

    return Scaffold(
      body: PageBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            children: [
              Row(
                children: [
                  AppIconButton(
                    icon: PhosphorIconsRegular.caretLeft,
                    label: 'Back',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text('Cheat', textAlign: TextAlign.center, style: AppText.heading(context)),
                    ),
                  ),
                  AppIconButton(
                    icon: fav ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
                    label: fav ? 'Remove from favourites' : 'Save to favourites',
                    color: fav ? AppColors.accent : AppColors.text,
                    onPressed: () => app.toggleFavourite(cheat.id),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              GlassCard(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(cheat.category.label, style: AppText.caption(context)),
                              const SizedBox(height: 2),
                              Text(cheat.title, style: AppText.cardTitle(context)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        StatusBadge(status: cheat.status),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(cheat.summary, style: AppText.body(context).copyWith(color: AppColors.muted)),
                    if (cheat.addedIn != null) ...[
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: InfoTag(icon: PhosphorIconsRegular.tag, label: 'Works since ${cheat.addedIn}'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _PlatformSegments(
                      value: platform,
                      onChanged: app.setPlatform,
                    ),
                    const SizedBox(height: 16),
                    ButtonSequence(
                      glyphs: seq,
                      size: 44,
                      emptyText: 'No ${platform.short} release announced',
                    ),
                    if (cheat.isPlaceholder) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Placeholder layout – real codes are added after launch-day testing',
                        textAlign: TextAlign.center,
                        style: AppText.caption(context),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _CopyButton(
                      copied: _copied,
                      enabled: seq.isNotEmpty,
                      onPressed: () => _copy(cheat, platform),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('How to activate', style: AppText.heading(context)),
                    const SizedBox(height: 12),
                    for (final (i, step) in _steps(platform).indexed) ...[
                      _Step(number: i + 1, text: step),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Verification', style: AppText.heading(context)),
                    const SizedBox(height: 4),
                    Text(cheat.status.description, style: AppText.caption(context)),
                    const SizedBox(height: 14),
                    ...verificationMeters(context, cheat, app),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _OutlineAction(
                      icon: PhosphorIconsRegular.check,
                      label: vote == 1 ? 'Marked as working' : 'It works',
                      active: vote == 1,
                      onPressed: () => app.vote(cheat.id, 1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _OutlineAction(
                      icon: PhosphorIconsRegular.flag,
                      label: 'Report issue',
                      onPressed: () => _showReportSheet(context, cheat),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                kDisclaimer,
                textAlign: TextAlign.center,
                style: AppText.small(context).copyWith(color: AppColors.muted, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _steps(GamePlatform p) => [
        'Stand in an open area with room for the effect.',
        p == GamePlatform.pc
            ? 'PC input method will be added if a PC version is announced.'
            : 'Enter the sequence on your ${p.short} controller during gameplay, not in a menu.',
        'Watch for the on-screen confirmation, then rate it below.',
      ];

  void _showReportSheet(BuildContext context, Cheat cheat) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (sheetContext) => _ReportSheet(cheat: cheat),
    );
  }
}

class _PlatformSegments extends StatelessWidget {
  const _PlatformSegments({required this.value, required this.onChanged});
  final GamePlatform value;
  final ValueChanged<GamePlatform> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final p in GamePlatform.values)
            Expanded(
              child: Semantics(
                button: true,
                selected: p == value,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  height: 40,
                  decoration: BoxDecoration(
                    color: p == value ? AppColors.text : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => onChanged(p),
                      child: Center(
                        child: Text(
                          p.short,
                          style: AppText.label(context).copyWith(
                            color: p == value ? AppColors.dark : AppColors.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CopyButton extends StatelessWidget {
  const _CopyButton({required this.copied, required this.enabled, required this.onPressed});
  final bool copied;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: FilledButton(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          disabledBackgroundColor: AppColors.accent,
          disabledForegroundColor: Colors.white,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Row(
            key: ValueKey(copied),
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(copied ? PhosphorIconsBold.check : PhosphorIconsBold.copy, size: 18),
              const SizedBox(width: 8),
              Text(copied ? 'Copied' : 'Copy sequence'),
            ],
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});
  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: Text(
            '$number.',
            style: AppText.numeric(AppText.body(context)).copyWith(color: AppColors.accentSoft, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: AppText.body(context))),
      ],
    );
  }
}

class _OutlineAction extends StatelessWidget {
  const _OutlineAction({required this.icon, required this.label, required this.onPressed, this.active = false});
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? AppColors.accent.withValues(alpha: 0.15) : Colors.transparent,
        side: BorderSide(color: active ? AppColors.accent : AppColors.strokeStrong),
      ),
    );
  }
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.cheat});
  final Cheat cheat;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static const _reasons = [
    "The code doesn't work",
    'It works on a different platform',
    'The effect is different',
    'Something else',
  ];
  String? _reason;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Report “${widget.cheat.title}”', style: AppText.cardTitle(context)),
            const SizedBox(height: 4),
            Text('Reports help keep every entry accurate.', style: AppText.caption(context)),
            const SizedBox(height: 12),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final r in _reasons)
                    RadioListTile<String>(
                      value: r,
                      title: Text(r, style: AppText.body(context)),
                      activeColor: AppColors.accent,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _reason == null
                  ? null
                  : () {
                      final messenger = ScaffoldMessenger.of(context);
                      Navigator.of(context).pop();
                      messenger.showSnackBar(
                        const SnackBar(content: Text('Thanks – report saved on this device for now.')),
                      );
                    },
              child: const Text('Send report'),
            ),
          ],
        ),
      ),
    );
  }
}
