import 'package:flutter/material.dart';

import '../widgets/common.dart';
import '../widgets/floating_nav.dart';
import 'cheat_library_screen.dart';
import 'favourites_screen.dart';
import 'finder_screen.dart';
import 'secrets_screen.dart';
import 'vehicles_screen.dart';
import '../theme/phosphor.dart';

/// Root layout: plain background, one tab visible at a time, floating nav.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const finderIndex = 2;
  int _index = 0;
  final _finderFocus = FocusNode();

  static const _items = [
    NavItem(PhosphorIconsRegular.house, PhosphorIconsFill.house, 'Cheats'),
    NavItem(PhosphorIconsRegular.car, PhosphorIconsFill.car, 'Vehicles'),
    NavItem(PhosphorIconsRegular.magnifyingGlass, PhosphorIconsBold.magnifyingGlass, 'Quick cheat finder'),
    NavItem(PhosphorIconsRegular.heart, PhosphorIconsFill.heart, 'Favourites'),
    NavItem(PhosphorIconsRegular.mapTrifold, PhosphorIconsFill.mapTrifold, 'Map & secrets'),
  ];

  void _go(int i) {
    setState(() => _index = i);
    if (i == finderIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finderFocus.requestFocus());
    } else {
      _finderFocus.unfocus();
    }
  }

  @override
  void dispose() {
    _finderFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      CheatLibraryScreen(onOpenFinder: () => _go(finderIndex)),
      const VehiclesScreen(),
      FinderScreen(focusNode: _finderFocus),
      FavouritesScreen(onBrowse: () => _go(0)),
      const SecretsScreen(),
    ];

    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: PageBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: pages),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: FloatingNav(items: _items, index: _index, onTap: _go),
      ),
    );
  }
}

/// Bottom padding so scrolling content clears the floating nav.
const double kNavClearance = 110;
