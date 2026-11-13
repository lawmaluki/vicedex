import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class NavItem {
  const NavItem(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Floating pill nav. Every slot is a bare icon; the selected one turns
/// accent and switches to its filled variant.
class FloatingNav extends StatelessWidget {
  const FloatingNav({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
  });

  final List<NavItem> items;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.navSurface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.stroke),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < items.length; i++)
            _NavButton(item: items[i], selected: i == index, onTap: () => onTap(i)),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({required this.item, required this.selected, required this.onTap});
  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: item.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: item.label,
        excludeSemantics: true,
        child: InkResponse(
          onTap: onTap,
          radius: 26,
          child: SizedBox(
            width: 48,
            height: 48,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 160),
              child: Icon(
                selected ? item.activeIcon : item.icon,
                key: ValueKey(selected),
                size: 24,
                color: selected ? AppColors.accent : AppColors.muted,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
