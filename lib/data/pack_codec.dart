import '../models/models.dart';
import 'content_pack.dart';

/// Decodes the JSON content pack built by `backend/ingest/build_pack.py`.
///
/// The decoder is deliberately forgiving about *records* and strict about the
/// *envelope*: one malformed cheat should not blank the whole library, but a
/// pack with no version or no recognisable lists is rejected so the app falls
/// back to the previous good copy.
class PackFormatException implements Exception {
  PackFormatException(this.message);
  final String message;
  @override
  String toString() => 'PackFormatException: $message';
}

class PackCodec {
  const PackCodec();

  static const _statuses = {
    'verified': VerificationStatus.verified,
    'unverified': VerificationStatus.unverified,
    'rumour': VerificationStatus.rumour,
    'rumor': VerificationStatus.rumour,
  };
  static const _categories = {
    'weapons': CheatCategory.weapons,
    'vehicles': CheatCategory.vehicles,
    'player': CheatCategory.player,
    'world': CheatCategory.world,
  };
  static const _platforms = {
    'ps5': GamePlatform.ps5,
    'xbox': GamePlatform.xbox,
    'pc': GamePlatform.pc,
  };
  static const _classes = {
    'cars': VehicleClass.cars,
    'bikes': VehicleClass.bikes,
    'boats': VehicleClass.boats,
    'aircraft': VehicleClass.aircraft,
  };
  static const _stats = {
    'topSpeed': PerformanceStat.topSpeed,
    'acceleration': PerformanceStat.acceleration,
    'handling': PerformanceStat.handling,
    'braking': PerformanceStat.braking,
  };
  static const _editions = {
    'standard': GameEdition.standard,
    'ultimate': GameEdition.ultimate,
  };

  ContentPack decode(Object? json) {
    if (json is! Map) {
      throw PackFormatException('pack root must be an object, got ${json.runtimeType}');
    }
    final version = json['version'];
    if (version is! int) {
      throw PackFormatException('pack version missing or not an int');
    }
    if (json['cheats'] is! List && json['vehicles'] is! List) {
      throw PackFormatException('pack has neither a cheats nor a vehicles list');
    }

    return ContentPack(
      version: version,
      generatedAt: _date(json['generatedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      etag: json['etag'] as String? ?? '',
      cheats: _list(json['cheats'], _cheat),
      vehicles: _list(json['vehicles'], _vehicle),
      secrets: _list(json['secrets'], _secret),
      notices: _list(json['notices'], _notice),
      sources: _list(json['sources'], _source),
    );
  }

  /// Decodes each element, dropping any that throws. A single bad record must
  /// not cost the user the entire list.
  List<T> _list<T>(Object? raw, T? Function(Map<dynamic, dynamic>) decode) {
    if (raw is! List) return const [];
    final out = <T>[];
    for (final item in raw) {
      if (item is! Map) continue;
      try {
        final decoded = decode(item);
        if (decoded != null) out.add(decoded);
      } catch (_) {
        // Skip the record; the rest of the pack is still usable.
      }
    }
    return List.unmodifiable(out);
  }

  Cheat? _cheat(Map<dynamic, dynamic> m) {
    final id = m['id'] as String?;
    final title = m['title'] as String?;
    if (id == null || title == null) return null;

    final sequences = <GamePlatform, List<String>>{};
    final raw = m['sequences'];
    if (raw is Map) {
      raw.forEach((key, value) {
        final platform = _platforms[key];
        if (platform == null || value is! List) return;
        final glyphs = value.whereType<String>().toList(growable: false);
        if (glyphs.isNotEmpty) sequences[platform] = List.unmodifiable(glyphs);
      });
    }

    return Cheat(
      id: id,
      title: title,
      category: _categories[m['category']] ?? CheatCategory.world,
      summary: m['summary'] as String? ?? '',
      keywords: (m['keywords'] as List?)?.whereType<String>().toList(growable: false) ?? const [],
      status: _statuses[m['status']] ?? VerificationStatus.rumour,
      sequences: Map.unmodifiable(sequences),
      confirmations: _int(m['confirmations']) ?? 0,
      lastTested: _date(m['lastTested']),
      // A record from the pipeline is real data, not a layout stand-in.
      isPlaceholder: m['isPlaceholder'] as bool? ?? false,
      addedIn: m['addedIn'] as String?,
      game: m['game'] as String? ?? kCurrentGame,
      provenance: _provenance(m['provenance']),
    );
  }

  Vehicle? _vehicle(Map<dynamic, dynamic> m) {
    final id = m['id'] as String?;
    final name = m['name'] as String?;
    if (id == null || name == null) return null;

    final performance = <PerformanceStat, double>{};
    final rawPerf = m['performance'];
    if (rawPerf is Map) {
      rawPerf.forEach((key, value) {
        final stat = _stats[key];
        final number = _double(value);
        // Out-of-range values would overflow the meters, so clamp rather than
        // drop: a measured-but-odd figure is still worth showing.
        if (stat != null && number != null) {
          performance[stat] = number.clamp(0.0, 1.0).toDouble();
        }
      });
    }

    final rawSpecs = m['specs'] is Map ? m['specs'] as Map : const {};
    return Vehicle(
      id: id,
      name: name,
      vehicleClass: _classes[m['vehicleClass']] ?? VehicleClass.cars,
      status: _statuses[m['status']] ?? VerificationStatus.rumour,
      specs: VehicleSpecs(
        manufacturer: rawSpecs['manufacturer'] as String?,
        topSpeedMph: _double(rawSpecs['topSpeedMph']),
        seats: _int(rawSpecs['seats']),
        doors: _int(rawSpecs['doors']),
        drivetrain: rawSpecs['drivetrain'] as String?,
        gears: _int(rawSpecs['gears']),
        weightKg: _int(rawSpecs['weightKg']),
      ),
      performance: Map.unmodifiable(performance),
      exclusiveTo: _editions[m['exclusiveTo']],
      addedIn: m['addedIn'] as String?,
      provenance: _provenance(m['provenance']),
      returning: m['returning'] as bool? ?? false,
      wikiClass: m['wikiClass'] as String?,
    );
  }

  Secret? _secret(Map<dynamic, dynamic> m) {
    final id = m['id'] as String?;
    final title = m['title'] as String?;
    if (id == null || title == null) return null;
    return Secret(
      id: id,
      title: title,
      area: m['area'] as String? ?? 'Unknown area',
      summary: m['summary'] as String? ?? '',
      status: _statuses[m['status']] ?? VerificationStatus.rumour,
      provenance: _provenance(m['provenance']),
    );
  }

  ContentNotice? _notice(Map<dynamic, dynamic> m) {
    final id = m['id'] as String?;
    final title = m['title'] as String?;
    if (id == null || title == null) return null;
    return ContentNotice(
      id: id,
      scope: m['scope'] as String? ?? 'cheats',
      title: title,
      body: m['body'] as String? ?? '',
      severity: m['severity'] as String? ?? 'info',
      source: m['source'] as String?,
    );
  }

  ContentSource? _source(Map<dynamic, dynamic> m) {
    final name = m['name'] as String?;
    if (name == null) return null;
    return ContentSource(
      name: name,
      url: m['url'] as String? ?? '',
      licence: m['licence'] as String? ?? '',
    );
  }

  Provenance? _provenance(Object? raw) {
    if (raw is! Map) return null;
    final source = raw['source'] as String?;
    if (source == null) return null;
    return Provenance(
      sourceName: raw['sourceName'] as String? ?? 'Unknown source',
      source: source,
      licence: raw['licence'] as String? ?? '',
      note: raw['note'] as String?,
      sighting: raw['sighting'] as String?,
    );
  }

  static int? _int(Object? v) =>
      v is int ? v : (v is num ? v.toInt() : (v is String ? int.tryParse(v) : null));

  static double? _double(Object? v) =>
      v is double ? v : (v is num ? v.toDouble() : (v is String ? double.tryParse(v) : null));

  static DateTime? _date(Object? v) => v is String ? DateTime.tryParse(v)?.toLocal() : null;
}
