import '../models/models.dart';

/// FRONTEND MOCK DATA
///
/// Rockstar has not confirmed any GTA VI cheat codes. Every entry below is a
/// layout placeholder marked as a Rumour so the UI can be built and tested
/// before launch. Replace this file with your CMS / Supabase source and only
/// mark entries Verified after testing them in the released game.
class MockData {
  MockData._();

  static const _ps = ['○', '△', 'L1', 'R1', '□', '✕', 'L2', 'R2'];
  static const _xb = ['B', 'Y', 'LB', 'RB', 'X', 'A', 'LT', 'RT'];

  /// Builds a deterministic placeholder sequence per entry, mirrored across
  /// PS5 and Xbox so the platform switch visibly changes the glyphs.
  static Map<GamePlatform, List<String>> _placeholder(List<int> pattern) => {
        GamePlatform.ps5: [for (final i in pattern) _ps[i]],
        GamePlatform.xbox: [for (final i in pattern) _xb[i]],
      };

  static final List<Cheat> cheats = [
    Cheat(
      id: 'spawn-helicopter',
      title: 'Spawn Helicopter',
      category: CheatCategory.vehicles,
      summary: 'Spawns a helicopter next to the player.',
      keywords: const ['heli', 'chopper', 'aircraft', 'spawn', 'fly'],
      status: VerificationStatus.rumour,
      sequences: _placeholder(const [0, 0, 2, 0, 0, 0, 2, 6]),
    ),
    Cheat(
      id: 'spawn-sports-car',
      title: 'Spawn Sports Car',
      category: CheatCategory.vehicles,
      summary: 'Spawns a fast two-door car in front of the player.',
      keywords: const ['car', 'fast', 'spawn', 'drive'],
      status: VerificationStatus.rumour,
      sequences: _placeholder(const [3, 2, 0, 3, 6, 5, 0, 7]),
    ),
    Cheat(
      id: 'spawn-boat',
      title: 'Spawn Speedboat',
      category: CheatCategory.vehicles,
      summary: 'Spawns a speedboat. Use near water.',
      keywords: const ['boat', 'water', 'spawn', 'sea'],
      status: VerificationStatus.rumour,
      sequences: _placeholder(const [1, 1, 4, 5, 3, 2, 2, 4]),
    ),
    Cheat(
      id: 'max-health',
      title: 'Max Health & Armour',
      category: CheatCategory.player,
      summary: 'Refills health and armour.',
      keywords: const ['health', 'armor', 'armour', 'heal', 'god'],
      status: VerificationStatus.rumour,
      sequences: _placeholder(const [0, 2, 1, 7, 5, 4, 0, 3]),
    ),
    Cheat(
      id: 'super-jump',
      title: 'Super Jump',
      category: CheatCategory.player,
      summary: 'Lets the player jump much higher.',
      keywords: const ['jump', 'high', 'ability'],
      status: VerificationStatus.rumour,
      sequences: _placeholder(const [6, 6, 1, 1, 7, 2, 3, 5]),
    ),
    Cheat(
      id: 'weapon-set',
      title: 'Weapon Set',
      category: CheatCategory.weapons,
      summary: 'Gives the player a set of weapons and ammo.',
      keywords: const ['guns', 'ammo', 'weapons', 'arsenal'],
      status: VerificationStatus.rumour,
      sequences: _placeholder(const [7, 4, 6, 3, 2, 0, 5, 1]),
    ),
    Cheat(
      id: 'explosive-melee',
      title: 'Explosive Melee',
      category: CheatCategory.weapons,
      summary: 'Melee hits cause explosions.',
      keywords: const ['punch', 'explode', 'melee', 'fist'],
      status: VerificationStatus.rumour,
      sequences: _placeholder(const [3, 0, 1, 0, 4, 6, 3, 2]),
    ),
    Cheat(
      id: 'lower-wanted',
      title: 'Lower Wanted Level',
      category: CheatCategory.world,
      summary: 'Removes one wanted star.',
      keywords: const ['police', 'cops', 'wanted', 'stars'],
      status: VerificationStatus.rumour,
      sequences: _placeholder(const [3, 3, 0, 7, 4, 2, 0, 5]),
    ),
    Cheat(
      id: 'change-weather',
      title: 'Change Weather',
      category: CheatCategory.world,
      summary: 'Cycles through weather conditions.',
      keywords: const ['weather', 'rain', 'sun', 'storm'],
      status: VerificationStatus.rumour,
      sequences: _placeholder(const [7, 5, 2, 2, 6, 6, 6, 4]),
    ),
  ];

  /// Sample vehicles. Specs are invented layout values for the "Sample"
  /// entries only, so the spec sheet, class rank and TBD states can all be
  /// seen. Several entries are left unmeasured on purpose.
  static const List<Vehicle> vehicles = [
    Vehicle(
      id: 'car-1',
      name: 'Sample coupe',
      vehicleClass: VehicleClass.cars,
      status: VerificationStatus.rumour,
      addedIn: 'Launch 1.0',
      specs: VehicleSpecs(
        manufacturer: 'Sample Motors',
        topSpeedMph: 121,
        seats: 2,
        doors: 2,
        drivetrain: 'RWD',
        gears: 6,
        weightKg: 1420,
      ),
      performance: {
        PerformanceStat.topSpeed: 0.82,
        PerformanceStat.acceleration: 0.78,
        PerformanceStat.handling: 0.7,
        PerformanceStat.braking: 0.65,
      },
    ),
    Vehicle(
      id: 'car-2',
      name: 'Sample SUV',
      vehicleClass: VehicleClass.cars,
      status: VerificationStatus.rumour,
      addedIn: 'Launch 1.0',
      specs: VehicleSpecs(
        manufacturer: 'Sample Motors',
        topSpeedMph: 104.5,
        seats: 4,
        doors: 4,
        drivetrain: 'AWD',
        weightKg: 2250,
      ),
      performance: {
        PerformanceStat.topSpeed: 0.6,
        PerformanceStat.acceleration: 0.52,
      },
    ),
    Vehicle(
      id: 'car-3',
      name: 'Sample muscle car',
      vehicleClass: VehicleClass.cars,
      status: VerificationStatus.rumour,
      exclusiveTo: GameEdition.ultimate,
      addedIn: 'Launch 1.0',
      specs: VehicleSpecs(
        manufacturer: 'Sample Works',
        topSpeedMph: 112.5,
        seats: 2,
        doors: 2,
        drivetrain: 'RWD',
        gears: 5,
        weightKg: 1680,
      ),
    ),
    Vehicle(
      id: 'bike-1',
      name: 'Sample sport bike',
      vehicleClass: VehicleClass.bikes,
      status: VerificationStatus.rumour,
      specs: VehicleSpecs(manufacturer: 'Sample Moto', topSpeedMph: 126, seats: 2, gears: 6, weightKg: 190),
    ),
    Vehicle(
      id: 'bike-2',
      name: 'Sample dirt bike',
      vehicleClass: VehicleClass.bikes,
      status: VerificationStatus.rumour,
      specs: VehicleSpecs(topSpeedMph: 88),
    ),
    Vehicle(id: 'boat-1', name: 'Sample speedboat', vehicleClass: VehicleClass.boats, status: VerificationStatus.rumour),
    Vehicle(id: 'boat-2', name: 'Sample airboat', vehicleClass: VehicleClass.boats, status: VerificationStatus.rumour),
    Vehicle(id: 'air-1', name: 'Sample helicopter', vehicleClass: VehicleClass.aircraft, status: VerificationStatus.rumour),
    Vehicle(id: 'air-2', name: 'Sample seaplane', vehicleClass: VehicleClass.aircraft, status: VerificationStatus.rumour),
  ];

  static const List<Secret> secrets = [
    Secret(
      id: 's-1',
      title: 'Placeholder easter egg',
      area: 'Area to be confirmed',
      summary: 'Hidden discoveries appear here after launch-day testing.',
      status: VerificationStatus.rumour,
    ),
    Secret(
      id: 's-2',
      title: 'Placeholder collectible',
      area: 'Area to be confirmed',
      summary: 'Community reports land here as Unverified until tested.',
      status: VerificationStatus.rumour,
    ),
  ];

  /// Shown in the Quick Cheat Finder before the user types.
  static const suggestions = ['spawn helicopter', 'health', 'weapons', 'wanted', 'jump'];
}
