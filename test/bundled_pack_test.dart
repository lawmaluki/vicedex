import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vicedex/data/pack_codec.dart';
import 'package:vicedex/models/models.dart';

/// Guards the real `assets/content_pack.json` that ships in the app.
///
/// The pack is regenerated from the GTA Wiki, so this asserts the invariants
/// that must hold for any build of it rather than specific contents.
void main() {
  const codec = PackCodec();

  late final pack = codec.decode(
    jsonDecode(File('assets/content_pack.json').readAsStringSync()),
  );

  test('the bundled pack decodes', () {
    expect(pack.version, greaterThan(0));
    expect(pack.etag, isNotEmpty);
    expect(pack.vehicles, isNotEmpty);
  });

  test('ids are unique across the pack', () {
    final ids = [
      ...pack.cheats.map((c) => c.id),
      ...pack.vehicles.map((v) => v.id),
      ...pack.secrets.map((s) => s.id),
    ];
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('wiki secrets are never marked verified', () {
    // Cheat codes and vehicles in a released game can be verified from the game
    // itself. A secret is a community write-up, and a scrape cannot establish
    // that anyone reproduced it.
    expect(
      pack.secrets.where((s) => s.status == VerificationStatus.verified),
      isEmpty,
    );
  });

  test('the pack is for the current game', () {
    expect(pack.currentGameCheats, isNotEmpty);
    expect(pack.legacyCheats, isEmpty);
  });

  test('every cheat has at least one platform sequence', () {
    for (final cheat in pack.cheats) {
      expect(
        GamePlatform.values.any((p) => cheat.sequenceFor(p).isNotEmpty),
        isTrue,
        reason: '${cheat.id} has no code for any platform',
      );
    }
  });

  test('records carry source attribution, as CC BY-SA requires', () {
    for (final vehicle in pack.vehicles) {
      expect(vehicle.provenance, isNotNull, reason: '${vehicle.id} has no source');
      expect(vehicle.provenance!.licence, isNotEmpty);
    }
    for (final cheat in pack.cheats) {
      expect(cheat.provenance, isNotNull, reason: '${cheat.id} has no source');
    }
  });

  test('an empty content list is explained by a notice', () {
    // An empty screen with no explanation reads as a broken app.
    if (pack.currentGameCheats.isEmpty) {
      expect(pack.noticesFor('cheats'), isNotEmpty);
    }
    if (pack.secrets.isEmpty) {
      expect(pack.noticesFor('secrets'), isNotEmpty);
    }
  });
}
