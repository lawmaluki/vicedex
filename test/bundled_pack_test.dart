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

  test('no GTA VI entry claims to be verified without being tested', () {
    // Verified means confirmed in the released game. A scrape cannot establish
    // that, so anything the pipeline marks verified must be a legacy GTA V
    // code, where it is true.
    final wronglyVerified = [
      ...pack.currentGameCheats.where((c) => c.status == VerificationStatus.verified),
      ...pack.vehicles.where((v) => v.status == VerificationStatus.verified),
      ...pack.secrets.where((s) => s.status == VerificationStatus.verified),
    ];
    expect(wronglyVerified, isEmpty);
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
