import '../models/models.dart';

/// A notice carried by the pack and rendered by the app, e.g. "no GTA VI cheat
/// codes are confirmed yet". Written by the ingest pipeline so the explanation
/// can change without shipping a new build.
class ContentNotice {
  const ContentNotice({
    required this.id,
    required this.scope,
    required this.title,
    required this.body,
    this.severity = 'info',
    this.source,
  });

  final String id;

  /// Which screen it belongs to: `cheats`, `vehicles`, `secrets`.
  final String scope;
  final String title;
  final String body;
  final String severity;
  final String? source;
}

class ContentSource {
  const ContentSource({required this.name, required this.url, required this.licence});
  final String name;
  final String url;
  final String licence;
}

/// Everything static the app displays, as built by `backend/ingest`.
///
/// One immutable snapshot. The app never mutates it; user state (favourites,
/// votes) lives in [AppState] and the backend, keyed by entity id.
class ContentPack {
  const ContentPack({
    required this.version,
    required this.generatedAt,
    required this.etag,
    required this.cheats,
    required this.vehicles,
    required this.secrets,
    this.notices = const [],
    this.sources = const [],
  });

  final int version;
  final DateTime generatedAt;

  /// Content hash of the records. Equal etags mean identical content, so the
  /// app can skip a download even when `generatedAt` moved.
  final String etag;

  final List<Cheat> cheats;
  final List<Vehicle> vehicles;
  final List<Secret> secrets;
  final List<ContentNotice> notices;
  final List<ContentSource> sources;

  /// Used before any pack has loaded. Not const: `DateTime` has no const
  /// constructor.
  static final empty = ContentPack(
    version: 0,
    generatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    etag: '',
    cheats: const [],
    vehicles: const [],
    secrets: const [],
  );

  bool get isEmpty => cheats.isEmpty && vehicles.isEmpty && secrets.isEmpty;

  List<ContentNotice> noticesFor(String scope) =>
      notices.where((n) => n.scope == scope).toList(growable: false);

  /// Cheats for [kCurrentGame]. Codes from any other game are excluded: they
  /// are reference material, not codes for this game.
  List<Cheat> get currentGameCheats =>
      cheats.where((c) => c.game == kCurrentGame).toList(growable: false);

  List<Cheat> get legacyCheats =>
      cheats.where((c) => c.game != kCurrentGame).toList(growable: false);
}
