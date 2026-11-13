import 'package:flutter/material.dart';

import '../data/mock_data.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'cheat_library_screen.dart' show openCheat;
import 'shell.dart';
import '../theme/phosphor.dart';

/// Quick Cheat Finder: type "spawn helicopter", get the instructions for
/// the selected platform immediately.
class FinderScreen extends StatefulWidget {
  const FinderScreen({super.key, required this.focusNode});
  final FocusNode focusNode;

  @override
  State<FinderScreen> createState() => _FinderScreenState();
}

class _FinderScreenState extends State<FinderScreen> {
  final _controller = TextEditingController();
  VerificationStatus? _status; // null = all

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _setQuery(String q) {
    _controller.value = TextEditingValue(text: q, selection: TextSelection.collapsed(offset: q.length));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final query = _controller.text;
    final results = app.cheats
        .where((c) => c.matches(query))
        .where((c) => _status == null || c.status == _status)
        .toList();

    final statusFilters = <VerificationStatus?>[null, ...VerificationStatus.values];

    return ListView(
      padding: const EdgeInsets.only(bottom: kNavClearance),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      children: [
        ScreenHeader(
          title: 'Quick Cheat Finder',
          caption: 'Showing ${app.platform.label} instructions',
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SearchPill(
            controller: _controller,
            focusNode: widget.focusNode,
            hint: 'What do you want to do?',
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(height: 14),
        PillChips<VerificationStatus?>(
          items: statusFilters,
          selected: _status,
          labelOf: (s) => s?.label ?? 'All statuses',
          onSelected: (s) => setState(() => _status = s),
        ),
        const SizedBox(height: 18),
        if (query.trim().isEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text('Popular searches', style: AppText.heading(context)),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in MockData.suggestions)
                  ActionChip(
                    label: Text(s),
                    onPressed: () => _setQuery(s),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (results.isEmpty)
          EmptyState(
            icon: PhosphorIconsRegular.magnifyingGlass,
            title: 'No matches',
            message: _status == VerificationStatus.verified
                ? 'Nothing is verified yet. Entries are tested once the game is out.'
                : 'Try another word, like “health” or “wanted”.',
          )
        else ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Text('${results.length} result${results.length == 1 ? '' : 's'}',
                style: AppText.numeric(AppText.caption(context))),
          ),
          for (final c in results)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: _FinderResult(cheat: c, platform: app.platform),
            ),
        ],
      ],
    );
  }
}

/// Result row that shows the sequence inline, so the answer is one glance away.
class _FinderResult extends StatelessWidget {
  const _FinderResult({required this.cheat, required this.platform});
  final Cheat cheat;
  final GamePlatform platform;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: () => openCheat(context, cheat),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(cheat.category.icon, size: 20, color: AppColors.accentSoft),
              const SizedBox(width: 10),
              Expanded(
                child: Text(cheat.title, style: AppText.itemTitle(context)),
              ),
              StatusBadge(status: cheat.status, compact: true),
            ],
          ),
          const SizedBox(height: 12),
          ButtonSequence(
            glyphs: cheat.sequenceFor(platform),
            size: 34,
            emptyText: 'No ${platform.short} release announced',
          ),
        ],
      ),
    );
  }
}
