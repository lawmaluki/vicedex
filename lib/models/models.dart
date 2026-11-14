import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/phosphor.dart';

enum GamePlatform {
  ps5('PlayStation 5', 'PS5', 'Console'),
  xbox('Xbox Series X|S', 'Xbox', 'Console'),
  pc('PC', 'PC', 'Not announced');

  const GamePlatform(this.label, this.short, this.subtitle);
  final String label;
  final String short;
  final String subtitle;
}

/// Every piece of content carries one of these. Nothing is shown as
/// confirmed until it has been tested in the released game.
enum VerificationStatus {
  verified('Verified', 'Tested in the released game', AppColors.verified),
  unverified('Unverified', 'Community-reported, awaiting testing', AppColors.unverified),
  rumour('Rumour', 'Speculation, clearly labelled', AppColors.rumour);

  const VerificationStatus(this.label, this.description, this.color);
  final String label;
  final String description;
  final Color color;

  /// 0..1 position on the verification meter.
  double get progress => switch (this) {
        VerificationStatus.rumour => 0.12,
        VerificationStatus.unverified => 0.5,
        VerificationStatus.verified => 1.0,
      };
}

enum CheatCategory {
  all('All', PhosphorIconsRegular.squaresFour),
  weapons('Weapons', PhosphorIconsRegular.crosshair),
  vehicles('Vehicles', PhosphorIconsRegular.car),
  player('Player', PhosphorIconsRegular.user),
  world('World', PhosphorIconsRegular.globeHemisphereWest);

  const CheatCategory(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// Where a record came from. The GTA Wiki is CC BY-SA, so attribution has to
/// travel with the data and be shown wherever the record is.
class Provenance {
  const Provenance({
    required this.sourceName,
    required this.source,
    required this.licence,
    this.note,
    this.sighting,
  });

  final String sourceName;
  final String source;
  final String licence;

  /// Plain-language reason for the record's status, e.g. "Seen in an official
  /// trailer (Trailer 1: 0:46)."
  final String? note;

  /// The raw sighting the wiki recorded, e.g. "Trailer 2: 2:28-2:30".
  final String? sighting;
}

class Cheat {
  const Cheat({
    required this.id,
    required this.title,
    required this.category,
    required this.summary,
    required this.keywords,
    required this.status,
    required this.sequences,
    this.confirmations = 0,
    this.lastTested,
    this.isPlaceholder = true,
    this.addedIn,
    this.game = 'VI',
    this.provenance,
  });

  final String id;
  final String title;
  final CheatCategory category;
  final String summary;
  final List<String> keywords;
  final VerificationStatus status;

  /// Button inputs per platform. A missing platform means no code is known.
  final Map<GamePlatform, List<String>> sequences;
  final int confirmations;
  final DateTime? lastTested;

  /// True while the sequence is a layout placeholder, not a real code.
  final bool isPlaceholder;

  /// Game version the code first worked in, e.g. "Launch 1.0". Codes can
  /// change between patches, so this tells players whether it still applies.
  final String? addedIn;

  /// Which game the code belongs to: `VI`, or `V` for the legacy reference set
  /// shipped while no GTA VI codes are confirmed.
  final String game;

  final Provenance? provenance;

  bool get isLegacy => game != 'VI';

  List<String> sequenceFor(GamePlatform p) => sequences[p] ?? const [];

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = [title, summary, category.label, ...keywords].join(' ').toLowerCase();
    // Every word of the query must appear somewhere, so "spawn heli" works.
    return q.split(RegExp(r'\s+')).every(haystack.contains);
  }
}

enum VehicleClass {
  cars('Cars', PhosphorIconsRegular.car),
  bikes('Bikes', PhosphorIconsRegular.motorcycle),
  boats('Boats', PhosphorIconsRegular.boat),
  aircraft('Aircraft', PhosphorIconsRegular.airplane);

  const VehicleClass(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// The four standard handling ratings, each stored as 0..1.
enum PerformanceStat {
  topSpeed('Top speed'),
  acceleration('Acceleration'),
  handling('Handling'),
  braking('Braking');

  const PerformanceStat(this.label);
  final String label;
}

enum GameEdition {
  standard('Standard Edition'),
  ultimate('Ultimate Edition');

  const GameEdition(this.label);
  final String label;
}

/// Measured specs. Any null field is shown as "TBD".
class VehicleSpecs {
  const VehicleSpecs({
    this.manufacturer,
    this.topSpeedMph,
    this.seats,
    this.doors,
    this.drivetrain,
    this.gears,
    this.weightKg,
  });

  final String? manufacturer;
  final double? topSpeedMph;
  final int? seats;
  final int? doors;
  final String? drivetrain;
  final int? gears;
  final int? weightKg;
}

class Vehicle {
  const Vehicle({
    required this.id,
    required this.name,
    required this.vehicleClass,
    required this.status,
    this.specs = const VehicleSpecs(),
    this.performance = const {},
    this.exclusiveTo,
    this.addedIn,
    this.provenance,
    this.returning = false,
    this.wikiClass,
  });

  final String id;
  final String name;
  final VehicleClass vehicleClass;
  final VerificationStatus status;
  final VehicleSpecs specs;

  /// Empty until measured in the released game.
  final Map<PerformanceStat, double> performance;

  /// Edition required to own it; null means every edition.
  final GameEdition? exclusiveTo;

  /// Game version it was added in, e.g. "Launch 1.0".
  final String? addedIn;

  final Provenance? provenance;

  /// True when the vehicle also appeared in an earlier GTA game.
  final bool returning;

  /// The finer-grained class the source used, e.g. "Sports & super cars".
  /// Shown as a subtitle; [vehicleClass] is what the filters use.
  final String? wikiClass;
}

/// Where [v] places by top speed among vehicles of its class that have a
/// measured top speed. Null when [v] itself has none.
({int position, int total})? speedRankInClass(Vehicle v, Iterable<Vehicle> all) {
  final speed = v.specs.topSpeedMph;
  if (speed == null) return null;
  final peers = all
      .where((o) => o.vehicleClass == v.vehicleClass && o.specs.topSpeedMph != null)
      .map((o) => o.specs.topSpeedMph!)
      .toList();
  // Ties share the higher place, so two equal cars are both "1st".
  final position = peers.where((s) => s > speed).length + 1;
  return (position: position, total: peers.length);
}

class Secret {
  const Secret({
    required this.id,
    required this.title,
    required this.area,
    required this.summary,
    required this.status,
    this.provenance,
  });

  final String id;
  final String title;
  final String area;
  final String summary;
  final VerificationStatus status;
  final Provenance? provenance;
}
