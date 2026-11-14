import 'package:flutter_test/flutter_test.dart';
import 'package:vicedex/data/pack_codec.dart';
import 'package:vicedex/models/models.dart';

import 'support/test_pack.dart';

void main() {
  const codec = PackCodec();

  test('decodes a well-formed pack', () {
    final pack = codec.decode(testPackJson());

    expect(pack.version, 1);
    expect(pack.etag, 'test');
    expect(pack.cheats, hasLength(1));
    expect(pack.vehicles, hasLength(3));

    final cheat = pack.cheats.single;
    expect(cheat.title, 'Spawn Helicopter');
    expect(cheat.category, CheatCategory.vehicles);
    expect(cheat.status, VerificationStatus.verified);
    expect(cheat.sequenceFor(GamePlatform.ps5), ['○', '○', 'L1', '○']);
    // No code was supplied for PC, which must read as "unknown", not empty.
    expect(cheat.sequenceFor(GamePlatform.pc), isEmpty);
    // Pipeline records are real data, so the placeholder flag defaults off.
    expect(cheat.isPlaceholder, isFalse);
  });

  test('splits current-game cheats from the legacy reference set', () {
    final pack = codec.decode(testPackJson(cheats: [
      {...sampleCheat, 'id': 'vi-1', 'game': 'VI'},
      {...sampleCheat, 'id': 'v-1', 'game': 'V', 'title': 'Legacy code'},
    ]));

    expect(pack.currentGameCheats.map((c) => c.id), ['vi-1']);
    expect(pack.legacyCheats.map((c) => c.id), ['v-1']);
    expect(pack.legacyCheats.single.isLegacy, isTrue);
  });

  test('drops unreadable records but keeps the rest of the list', () {
    // Built as a raw map so the list can hold a deliberately wrong type.
    final pack = codec.decode({
      ...testPackJson(),
      'cheats': [
        {'title': 'no id here'}, // dropped: no id
        'not even an object', // dropped: wrong type
        sampleCheat,
      ],
    });

    expect(pack.cheats.map((c) => c.id), ['test-spawn-helicopter']);
  });

  test('unknown enum values fall back rather than throwing', () {
    final pack = codec.decode(testPackJson(cheats: [
      {...sampleCheat, 'status': 'totally-made-up', 'category': 'nonsense'},
    ]));

    final cheat = pack.cheats.single;
    // An unrecognised status must never read as verified.
    expect(cheat.status, VerificationStatus.rumour);
    expect(cheat.category, CheatCategory.world);
  });

  test('performance ratings are clamped to 0..1', () {
    final pack = codec.decode(testPackJson(vehicles: [
      {
        'id': 'v1',
        'name': 'Clamped',
        'vehicleClass': 'cars',
        'status': 'rumour',
        'performance': {'topSpeed': 1.4, 'braking': -0.2, 'bogus': 0.5},
      },
    ]));

    final perf = pack.vehicles.single.performance;
    expect(perf[PerformanceStat.topSpeed], 1.0);
    expect(perf[PerformanceStat.braking], 0.0);
    expect(perf.containsKey(PerformanceStat.handling), isFalse);
  });

  test('rejects an envelope the app could not render', () {
    expect(() => codec.decode('nope'), throwsA(isA<PackFormatException>()));
    expect(() => codec.decode({'cheats': []}), throwsA(isA<PackFormatException>()));
    expect(() => codec.decode({'version': 1, 'secrets': []}),
        throwsA(isA<PackFormatException>()));
  });

  test('carries provenance so attribution survives into the UI', () {
    final pack = codec.decode(testPackJson(vehicles: [
      {
        'id': 'v1',
        'name': 'Attributed',
        'vehicleClass': 'cars',
        'status': 'unverified',
        'provenance': {
          'sourceName': 'GTA Wiki',
          'source': 'https://gta.fandom.com/wiki/Vehicles_in_GTA_VI',
          'licence': 'CC BY-SA 3.0',
          'sighting': 'Trailer 1: 0:46',
        },
      },
    ]));

    final prov = pack.vehicles.single.provenance;
    expect(prov, isNotNull);
    expect(prov!.licence, 'CC BY-SA 3.0');
    expect(prov.sighting, 'Trailer 1: 0:46');
  });
}
