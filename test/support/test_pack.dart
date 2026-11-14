import 'dart:convert';

import 'package:vicedex/data/backend_config.dart';
import 'package:vicedex/data/content_repository.dart';
import 'package:vicedex/data/pack_store.dart';
import 'package:vicedex/state/app_state.dart';

/// A small, fixed content pack for widget tests.
///
/// Tests must not depend on the real bundled pack: it is regenerated from the
/// GTA Wiki, so its contents change and assertions against specific names would
/// break for reasons that have nothing to do with the app.
Map<String, Object?> testPackJson({
  List<Map<String, Object?>>? cheats,
  List<Map<String, Object?>>? vehicles,
  List<Map<String, Object?>>? secrets,
  List<Map<String, Object?>>? notices,
}) =>
    {
      'version': 1,
      'generatedAt': '2026-11-14T00:00:00Z',
      'etag': 'test',
      'cheats': cheats ?? [sampleCheat],
      'vehicles': vehicles ?? sampleVehicles,
      'secrets': secrets ?? const [],
      'notices': notices ?? const [],
    };

const sampleCheat = {
  'id': 'test-spawn-helicopter',
  'title': 'Spawn Helicopter',
  'category': 'vehicles',
  'summary': 'Spawns a helicopter next to the player.',
  'keywords': ['heli', 'chopper', 'spawn'],
  'status': 'verified',
  'game': 'V',
  'sequences': {
    'ps5': ['○', '○', 'L1', '○'],
    'xbox': ['B', 'B', 'LB', 'B'],
  },
};

/// Three cars with measured speeds so rank, specs and TBD states are all
/// exercised: 121 > 112.5 > 104.5.
const sampleVehicles = [
  {
    'id': 'test-coupe',
    'name': 'Test coupe',
    'vehicleClass': 'cars',
    'status': 'unverified',
    'specs': {'topSpeedMph': 121.0, 'manufacturer': 'Test Motors', 'seats': 2},
  },
  {
    'id': 'test-muscle',
    'name': 'Test muscle car',
    'vehicleClass': 'cars',
    'status': 'rumour',
    'addedIn': 'Launch 1.0',
    'exclusiveTo': 'ultimate',
    'specs': {
      'topSpeedMph': 112.5,
      'manufacturer': 'Test Works',
      'seats': 2,
      'doors': 2,
      'drivetrain': 'RWD',
      'gears': 5,
      'weightKg': 1680,
    },
  },
  {
    'id': 'test-saloon',
    'name': 'Test saloon',
    'vehicleClass': 'cars',
    'status': 'rumour',
    'specs': {'topSpeedMph': 104.5},
  },
];

/// An [AppState] already loaded with [pack], and no backend configured.
Future<AppState> loadedState({Map<String, Object?>? pack}) async {
  final state = AppState(
    repository: ContentRepository(
      config: const BackendConfig(),
      packStore: PackStore(
        assetReader: (_) async => jsonEncode(pack ?? testPackJson()),
      ),
    ),
  );
  await state.load();
  return state;
}
