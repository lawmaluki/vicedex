import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import '../theme/phosphor.dart';

/// Plain page background.
class PageBackground extends StatelessWidget {
  const PageBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => ColoredBox(color: AppColors.background, child: child);
}

/// Translucent rounded surface used for every card.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 24,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.glass,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(radius),
        side: const BorderSide(color: AppColors.stroke),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// Bare icon button (no background shape) with a 44px tap target and a
/// tooltip that doubles as its accessible name.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.size = 44,
    this.iconSize = 22,
    this.color = AppColors.text,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: InkResponse(
        onTap: onPressed,
        radius: size / 2,
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(icon, size: iconSize, color: color, semanticLabel: label),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.status, this.compact = false});
  final VerificationStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Status: ${status.label}',
      child: Container(
        height: compact ? 24 : 28,
        padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: status.color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: status.color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            ExcludeSemantics(
              child: Text(
                status.label,
                style: (compact ? AppText.small(context) : AppText.label(context)).copyWith(color: status.color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small outlined label for facts like the game version or edition.
/// Same height as a compact [StatusBadge] so they sit together in a row.
class InfoTag extends StatelessWidget {
  const InfoTag({super.key, required this.label, this.icon, this.color = AppColors.muted});
  final String label;
  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.strokeStrong),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
          ],
          Text(label, style: AppText.small(context).copyWith(color: color)),
        ],
      ),
    );
  }
}

/// Two-column label/value sheet. Values of null render as "TBD".
class SpecGrid extends StatelessWidget {
  const SpecGrid({super.key, required this.rows});
  final List<(String label, String? value)> rows;

  @override
  Widget build(BuildContext context) {
    const gap = 16.0;
    return LayoutBuilder(builder: (context, box) {
      final cellWidth = (box.maxWidth - gap) / 2;
      return Wrap(
        spacing: gap,
        children: [
          for (final (label, value) in rows)
            Container(
              width: cellWidth,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.stroke))),
              child: Semantics(
                label: '$label: ${value ?? 'to be determined'}',
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: AppText.caption(context)),
                    const SizedBox(height: 2),
                    Text(
                      value ?? 'TBD',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.numeric(AppText.itemTitle(context))
                          .copyWith(color: value == null ? AppColors.muted : AppColors.text),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    });
  }
}

/// Flat progress bar with a label and value above it.
class MeterBar extends StatelessWidget {
  const MeterBar({super.key, required this.label, required this.value, required this.progress});
  final String label;
  final String value;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final double p = progress.clamp(0.0, 1.0).toDouble();
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: AppText.caption(context)),
              Text(value, style: AppText.numeric(AppText.label(context))),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: AppColors.glassStrong),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: p),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    builder: (context, t, _) => FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: t,
                      child: const ColoredBox(color: AppColors.accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Row of controller-button chips. Crossfades when the platform changes.
class ButtonSequence extends StatelessWidget {
  const ButtonSequence({super.key, required this.glyphs, this.size = 40, this.emptyText});
  final List<String> glyphs;
  final double size;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    final glyphStyle = AppText.label(context).copyWith(fontSize: size * 0.36, fontWeight: FontWeight.w600);
    final Widget content = glyphs.isEmpty
        ? Padding(
            key: const ValueKey('empty'),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(emptyText ?? 'No code for this platform', style: AppText.caption(context)),
          )
        : Wrap(
            key: ValueKey(glyphs.join()),
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final g in glyphs)
                Container(
                  constraints: BoxConstraints(minWidth: size, minHeight: size, maxHeight: size),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.strokeStrong),
                  ),
                  // widthFactor keeps the chip as wide as its glyph instead of the row.
                  child: Center(widthFactor: 1, child: Text(g, style: glyphStyle)),
                ),
            ],
          );

    return Semantics(
      label: glyphs.isEmpty ? (emptyText ?? 'No code') : 'Button sequence: ${glyphs.join(', ')}',
      excludeSemantics: true,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: content,
      ),
    );
  }
}

/// The sideways platform picker cards.
class PlatformCard extends StatelessWidget {
  const PlatformCard({super.key, required this.platform, required this.selected, required this.onTap});
  final GamePlatform platform;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 132,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: selected ? AppColors.accent : AppColors.stroke),
          color: selected ? AppColors.accent.withValues(alpha: 0.12) : AppColors.glass,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    platform == GamePlatform.pc ? PhosphorIconsRegular.desktop : PhosphorIconsRegular.gameController,
                    size: 24,
                    color: selected ? AppColors.accentSoft : AppColors.muted,
                  ),
                  const Spacer(),
                  Text(platform.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.itemTitle(context)),
                  const SizedBox(height: 2),
                  Text(platform.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal filter chips.
class PillChips<T> extends StatelessWidget {
  const PillChips({
    super.key,
    required this.items,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
  });

  final List<T> items;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          final on = item == selected;
          return Semantics(
            button: true,
            selected: on,
            child: Material(
              color: on ? AppColors.text : Colors.transparent,
              shape: StadiumBorder(side: BorderSide(color: on ? AppColors.text : AppColors.strokeStrong)),
              child: InkWell(
                customBorder: const StadiumBorder(),
                onTap: () => onSelected(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: Text(
                      labelOf(item),
                      style: AppText.label(context).copyWith(color: on ? AppColors.dark : AppColors.muted),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Pill-shaped search input.
class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onTap,
    this.autofocus = false,
    this.readOnly = false,
    this.focusNode,
  });

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String hint;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool autofocus;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.glass,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        children: [
          const Icon(PhosphorIconsRegular.magnifyingGlass, size: 20, color: AppColors.muted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: autofocus,
              readOnly: readOnly,
              onTap: onTap,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: AppText.body(context),
              cursorColor: AppColors.accent,
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: AppText.body(context).copyWith(color: AppColors.muted),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isCollapsed: true,
                semanticCounterText: '',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact row used in lists (finder results, favourites, category lists).
class CheatTile extends StatelessWidget {
  const CheatTile({super.key, required this.cheat, required this.onTap, this.trailing});
  final Cheat cheat;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
      onTap: onTap,
      child: Row(
        children: [
          Icon(cheat.category.icon, size: 22, color: AppColors.accentSoft),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cheat.title, style: AppText.itemTitle(context)),
                const SizedBox(height: 2),
                Text(cheat.category.label, style: AppText.caption(context)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing ?? StatusBadge(status: cheat.status, compact: true),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.message});
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.muted, size: 36),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: AppText.heading(context)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: AppText.caption(context).copyWith(height: 1.5)),
        ],
      ),
    );
  }
}

/// Screen header: title, optional caption, trailing actions.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.caption, this.actions = const []});
  final String title;
  final String? caption;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 10, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(header: true, child: Text(title, style: AppText.title(context))),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(caption!, style: AppText.caption(context)),
                ],
              ],
            ),
          ),
          ...actions,
        ],
      ),
    );
  }
}

const kDisclaimer = 'Independent fan-made companion. Not affiliated with or endorsed by Rockstar Games.';
