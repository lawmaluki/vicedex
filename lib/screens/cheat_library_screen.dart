import 'package:flutter/material.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'cheat_detail_screen.dart';
import 'shell.dart';
import 'submit_sheet.dart';
import '../theme/phosphor.dart';

class CheatLibraryScreen extends StatefulWidget {
  const CheatLibraryScreen({super.key, required this.onOpenFinder});
  final VoidCallback onOpenFinder;

  @override
  State<CheatLibraryScreen> createState() => _CheatLibraryScreenState();
}

class _CheatLibraryScreenState extends State<CheatLibraryScreen> {
  CheatCategory _category = CheatCategory.all;
  bool _cardView = true;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final list = app.visibleCheats
        .where((c) => _category == CheatCategory.all || c.category == _category)
        .toList();
    final featured = list.isEmpty ? null : list.first;
    // If the pack has no codes for the current game the library falls back to
    // another game's codes, so say which set is on screen.
    final showingLegacy = app.cheats.isEmpty && app.legacyCheats.isNotEmpty;

    if (app.status == LoadStatus.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: kNavClearance),
      children: [
        ScreenHeader(
          title: 'Cheat Library',
          caption: showingLegacy ? 'Codes from another GTA game · reference' : 'GTA V · Unofficial fan companion',
          actions: [
            AppIconButton(
              icon: PhosphorIconsBold.plus,
              label: 'Submit a cheat',
              color: AppColors.accent,
              onPressed: () => showSubmitSheet(context),
            ),
            _ViewToggle(cardView: _cardView, onChanged: (v) => setState(() => _cardView = v)),
          ],
        ),
        const SizedBox(height: 18),
        for (final notice in app.noticesFor('cheats')) NoticeCard(notice: notice),
        SizedBox(
          height: 112,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: GamePlatform.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              final p = GamePlatform.values[i];
              return PlatformCard(
                platform: p,
                selected: app.platform == p,
                onTap: () => app.setPlatform(p),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18),
          child: SearchPill(
            controller: null,
            hint: 'Try “spawn helicopter”',
            readOnly: true,
            onTap: widget.onOpenFinder,
          ),
        ),
        const SizedBox(height: 14),
        PillChips<CheatCategory>(
          items: CheatCategory.values,
          selected: _category,
          labelOf: (c) => c.label,
          onSelected: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: 16),
        if (featured == null)
          const EmptyState(
            icon: PhosphorIconsRegular.tray,
            title: 'Nothing here yet',
            message: 'Cheats for this category appear after launch-day testing.',
          )
        else if (_cardView) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: FeaturedCheatCard(key: ValueKey(featured.id), cheat: featured),
            ),
          ),
          const SizedBox(height: 20),
          if (list.length > 1) Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              _category == CheatCategory.all ? 'More cheats' : 'More ${_category.label.toLowerCase()}',
              style: AppText.heading(context),
            ),
          ),
          const SizedBox(height: 10),
          ..._tiles(context, list.skip(1).toList()),
        ] else
          ..._tiles(context, list),
      ],
    );
  }

  List<Widget> _tiles(BuildContext context, List<Cheat> list) => [
        for (final cheat in list)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: CheatTile(cheat: cheat, onTap: () => openCheat(context, cheat)),
          ),
      ];
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.cardView, required this.onChanged});
  final bool cardView;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(bool card, IconData icon, IconData activeIcon, String label) {
      final on = cardView == card;
      return Semantics(
        selected: on,
        child: AppIconButton(
          icon: on ? activeIcon : icon,
          label: label,
          color: on ? AppColors.text : AppColors.muted,
          onPressed: () => onChanged(card),
        ),
      );
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      seg(true, PhosphorIconsRegular.cards, PhosphorIconsFill.cards, 'Card view'),
      seg(false, PhosphorIconsRegular.rows, PhosphorIconsFill.rows, 'List view'),
    ]);
  }
}

/// The big card from the reference: category pill, favourite, sequence,
/// title, votes and the three pink meters.
class FeaturedCheatCard extends StatelessWidget {
  const FeaturedCheatCard({super.key, required this.cheat});
  final Cheat cheat;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final fav = app.isFavourite(cheat.id);
    final vote = app.voteFor(cheat.id);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(cheat.category.icon, size: 18, color: AppColors.muted),
              const SizedBox(width: 8),
              Text(cheat.category.label, style: AppText.label(context).copyWith(color: AppColors.muted)),
              const Spacer(),
              StatusBadge(status: cheat.status, compact: true),
              AppIconButton(
                icon: fav ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
                label: fav ? 'Remove from favourites' : 'Save to favourites',
                color: fav ? AppColors.accent : AppColors.text,
                onPressed: () => app.toggleFavourite(cheat.id),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ButtonSequence(
            glyphs: cheat.sequenceFor(app.platform),
            emptyText: 'No ${app.platform.short} release announced',
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (cheat.isPlaceholder) Text('Placeholder sequence', style: AppText.caption(context)),
                    const SizedBox(height: 2),
                    InkWell(
                      onTap: () => openCheat(context, cheat),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Flexible(child: Text(cheat.title, style: AppText.cardTitle(context))),
                        const SizedBox(width: 4),
                        const Icon(PhosphorIconsRegular.caretRight, size: 18, color: AppColors.muted),
                      ]),
                    ),
                  ],
                ),
              ),
              _VoteChip(
                icon: PhosphorIconsBold.caretUp,
                label: 'It works',
                count: app.worksCount(cheat),
                active: vote == 1,
                onTap: () => app.vote(cheat.id, 1),
              ),
              const SizedBox(width: 6),
              _VoteChip(
                icon: PhosphorIconsBold.caretDown,
                label: "Doesn't work",
                count: app.failsCount(cheat),
                active: vote == -1,
                onTap: () => app.vote(cheat.id, -1),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...verificationMeters(context, cheat, app),
        ],
      ),
    );
  }
}

/// The three meters shared by the featured card and the detail screen.
List<Widget> verificationMeters(BuildContext context, Cheat cheat, AppState app) {
  final confirmations = app.worksCount(cheat);
  return [
    MeterBar(label: 'Verification', value: cheat.status.label, progress: cheat.status.progress),
    const SizedBox(height: 12),
    MeterBar(
      label: 'Community confirmations',
      value: '$confirmations',
      progress: (confirmations / 50).clamp(0.0, 1.0).toDouble(),
    ),
    const SizedBox(height: 12),
    MeterBar(
      label: 'Last tested',
      value: cheat.lastTested == null ? 'Not yet' : _date(cheat.lastTested!),
      progress: cheat.lastTested == null ? 0 : 1,
    ),
  ];
}

String _date(DateTime d) => '${d.day}/${d.month}/${d.year}';

class _VoteChip extends StatelessWidget {
  const _VoteChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Semantics(
        button: true,
        selected: active,
        label: '$label, $count',
        excludeSemantics: true,
        child: Material(
          color: active ? AppColors.accent.withValues(alpha: 0.2) : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: active ? AppColors.accent : AppColors.strokeStrong),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 44,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(children: [
                  Icon(icon, size: 16, color: active ? AppColors.accentSoft : AppColors.text),
                  const SizedBox(width: 4),
                  Text('$count', style: AppText.numeric(AppText.label(context))),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void openCheat(BuildContext context, Cheat cheat) {
  Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (_, __, ___) => CheatDetailScreen(cheatId: cheat.id),
      transitionsBuilder: (_, anim, __, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(curved),
            child: child,
          ),
        );
      },
    ),
  );
}
