import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/models.dart';
import 'backend_client.dart';
import 'backend_config.dart';
import 'content_pack.dart';
import 'local_store.dart';
import 'pack_store.dart';

/// Single entry point to all data.
///
/// Reads come from the content pack (bundled, refreshed over HTTP). Writes --
/// votes, submissions, reports -- go to the backend when one is configured.
/// The UI never talks to either source directly, so running with no backend at
/// all is a supported mode rather than a broken one.
class ContentRepository {
  ContentRepository({
    this.config = BackendConfig.fromEnvironment,
    LocalStore? store,
    PackStore? packStore,
    BackendClient? backend,
  })  : _store = store ?? MemoryStore(),
        _packStore = packStore ?? PackStore(remoteUrl: config.packUrl) {
    _deviceId = _store.getString(_kDeviceId) ?? newDeviceId();
    // Persist immediately so a reinstall-free restart keeps the same identity
    // once a real LocalStore is wired in.
    _store.setString(_kDeviceId, _deviceId);
    _backend = backend ??
        BackendClient(config: config, deviceId: _deviceId);
  }

  static const _kDeviceId = 'vicedex.deviceId';
  static const _kFavourites = 'vicedex.favourites';
  static const _kVotes = 'vicedex.votes';

  final BackendConfig config;
  final LocalStore _store;
  final PackStore _packStore;
  late final BackendClient _backend;
  late final String _deviceId;

  ContentPack _pack = ContentPack.empty;
  PackOrigin _origin = PackOrigin.none;
  Object? _lastError;

  ContentPack get pack => _pack;
  PackOrigin get packOrigin => _origin;
  Object? get lastError => _lastError;
  bool get hasBackend => _backend.isConfigured;
  String get deviceId => _deviceId;

  /// Loads content. Safe to call more than once; later calls refresh.
  Future<ContentPack> load() async {
    final result = await _packStore.load();
    _pack = result.pack;
    _origin = result.origin;
    _lastError = result.error;
    if (result.error != null && kDebugMode) {
      debugPrint('ViceDex: pack refresh failed, serving ${result.origin.name}: ${result.error}');
    }

    // Registering the device is best-effort: failing it must not stop content
    // from appearing.
    if (_backend.isConfigured) {
      try {
        await _backend.registerDevice();
      } catch (error) {
        if (kDebugMode) debugPrint('ViceDex: device registration failed: $error');
      }
    }
    return _pack;
  }

  // --- favourites: local, authoritative -------------------------------------

  Set<String> loadFavourites() => _store.getStringList(_kFavourites).toSet();

  Future<void> saveFavourites(Set<String> ids) =>
      _store.setStringList(_kFavourites, ids.toList(growable: false));

  // --- votes ----------------------------------------------------------------

  /// This device's votes, as `cheatId:platform -> ±1`.
  Map<String, int> loadVotes() {
    final out = <String, int>{};
    for (final entry in _store.getStringList(_kVotes)) {
      final parts = entry.split('=');
      if (parts.length != 2) continue;
      final value = int.tryParse(parts[1]);
      if (value == 1 || value == -1) out[parts[0]] = value!;
    }
    return out;
  }

  Future<void> _saveVotes(Map<String, int> votes) => _store.setStringList(
      _kVotes, [for (final e in votes.entries) '${e.key}=${e.value}']);

  static String voteKey(String cheatId, GamePlatform platform) => '$cheatId:${platform.name}';

  /// Records a vote locally and pushes it to the backend.
  ///
  /// The local write happens first and is kept even if the network call fails,
  /// so the UI stays responsive offline. [BackendException] is rethrown so the
  /// caller can tell the user the tally may not have reached the server.
  Future<void> vote({
    required String cheatId,
    required GamePlatform platform,
    required int value,
  }) async {
    final votes = loadVotes();
    final key = voteKey(cheatId, platform);
    if (value == 0) {
      votes.remove(key);
    } else {
      votes[key] = value;
    }
    await _saveVotes(votes);

    if (!_backend.isConfigured) return;
    await _backend.vote(cheatId: cheatId, platform: platform, value: value);
  }

  /// Public tallies for the cheats currently on screen. Returns an empty map
  /// rather than throwing when there is no backend or the call fails: vote
  /// counts are decoration, not something worth an error state for.
  Future<Map<String, CheatTally>> tallies(List<String> cheatIds) async {
    if (!_backend.isConfigured || cheatIds.isEmpty) return const {};
    try {
      final rows = await _backend.tallies(cheatIds: cheatIds);
      return {for (final row in rows) voteKey(row.cheatId, row.platform): row};
    } catch (error) {
      if (kDebugMode) debugPrint('ViceDex: tally fetch failed: $error');
      return const {};
    }
  }

  // --- community writes -----------------------------------------------------

  Future<String> submitCheat({
    required String title,
    required CheatCategory category,
    required GamePlatform platform,
    required List<String> sequence,
    String? summary,
    String? sourceNote,
  }) =>
      _backend.submitCheat(
        title: title,
        category: category,
        platform: platform,
        sequence: sequence,
        summary: summary,
        sourceNote: sourceNote,
      );

  Future<void> reportCheat({
    required String cheatId,
    required String reason,
    GamePlatform? platform,
    String? gameBuild,
  }) =>
      _backend.reportCheat(
        cheatId: cheatId,
        reason: reason,
        platform: platform,
        gameBuild: gameBuild,
      );

  void dispose() {
    _packStore.dispose();
    _backend.dispose();
  }
}
