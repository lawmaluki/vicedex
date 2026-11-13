import 'package:flutter/widgets.dart';

/// Phosphor icons used by the app.
///
/// The phosphor_flutter package's Dart classes extend IconData, which is a
/// final class on current Flutter, so they no longer compile. The package is
/// kept only for its bundled icon fonts; glyphs are defined here instead.
/// Codepoints come from phosphor_flutter 2.1.0. To add an icon, copy its
/// codepoint from that package's phosphor_icons_<style>.dart.

class PhosphorIconsRegular {
  PhosphorIconsRegular._();
  static const airplane = IconData(0xe002, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const boat = IconData(0xe786, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const car = IconData(0xe112, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const cards = IconData(0xe0f8, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const caretLeft = IconData(0xe138, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const caretRight = IconData(0xe13a, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const check = IconData(0xe182, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const crosshair = IconData(0xe1d6, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const crownSimple = IconData(0xe616, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const desktop = IconData(0xe560, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const flag = IconData(0xe244, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const gameController = IconData(0xe26e, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const globeHemisphereWest = IconData(0xe28c, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const heart = IconData(0xe2a8, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const house = IconData(0xe2c2, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const magnifyingGlass = IconData(0xe30c, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const mapTrifold = IconData(0xe31a, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const motorcycle = IconData(0xe80a, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const rows = IconData(0xe5a2, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const sparkle = IconData(0xe6a2, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const squaresFour = IconData(0xe464, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const star = IconData(0xe46a, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const tag = IconData(0xe478, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const trash = IconData(0xe4a6, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const tray = IconData(0xe4aa, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const trophy = IconData(0xe67e, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
  static const user = IconData(0xe4c2, fontFamily: 'PhosphorRegular', fontPackage: _pkg);
}

class PhosphorIconsFill {
  PhosphorIconsFill._();
  static const car = IconData(0xe112, fontFamily: 'PhosphorFill', fontPackage: _pkg);
  static const cards = IconData(0xe0f8, fontFamily: 'PhosphorFill', fontPackage: _pkg);
  static const heart = IconData(0xe2a8, fontFamily: 'PhosphorFill', fontPackage: _pkg);
  static const house = IconData(0xe2c2, fontFamily: 'PhosphorFill', fontPackage: _pkg);
  static const mapTrifold = IconData(0xe31a, fontFamily: 'PhosphorFill', fontPackage: _pkg);
  static const rows = IconData(0xe5a2, fontFamily: 'PhosphorFill', fontPackage: _pkg);
  static const star = IconData(0xe46a, fontFamily: 'PhosphorFill', fontPackage: _pkg);
}

class PhosphorIconsBold {
  PhosphorIconsBold._();
  static const caretDown = IconData(0xe136, fontFamily: 'PhosphorBold', fontPackage: _pkg);
  static const caretUp = IconData(0xe13c, fontFamily: 'PhosphorBold', fontPackage: _pkg);
  static const check = IconData(0xe182, fontFamily: 'PhosphorBold', fontPackage: _pkg);
  static const copy = IconData(0xe1ca, fontFamily: 'PhosphorBold', fontPackage: _pkg);
  static const magnifyingGlass = IconData(0xe30c, fontFamily: 'PhosphorBold', fontPackage: _pkg);
  static const plus = IconData(0xe3d4, fontFamily: 'PhosphorBold', fontPackage: _pkg);
}

const _pkg = 'phosphor_flutter';
