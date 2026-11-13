import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'cheat_library_screen.dart' show openCheat;
import 'shell.dart';
import '../theme/phosphor.dart';

class FavouritesScreen extends StatelessWidget {
  const FavouritesScreen({super.key, required this.onBrowse});
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final favs = app.favouriteCheats;

    return ListView(
      padding: const EdgeInsets.only(bottom: kNavClearance),
      children: [
        ScreenHeader(
          title: 'Favourites',
          caption: favs.isEmpty ? 'Saved on this device' : '${favs.length} saved',
        ),
        const SizedBox(height: 18),
        if (favs.isEmpty) ...[
          const EmptyState(
            icon: PhosphorIconsRegular.star,
            title: 'No favourites yet',
            message: 'Tap the star on any cheat to keep it here for quick access.',
          ),
          Center(
            child: TextButton(
              onPressed: onBrowse,
                            child: const Text('Browse cheats'),
            ),
          ),
        ] else
          for (final c in favs)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
              child: Dismissible(
                key: ValueKey(c.id),
                direction: DismissDirection.endToStart,
                onDismissed: (_) => app.toggleFavourite(c.id),
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 24),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(PhosphorIconsRegular.trash, semanticLabel: 'Remove'),
                ),
                child: CheatTile(cheat: c, onTap: () => openCheat(context, c)),
              ),
            ),
      ],
    );
  }
}
