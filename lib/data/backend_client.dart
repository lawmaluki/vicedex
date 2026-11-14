import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/models.dart';
import 'backend_config.dart';

/// Raised when the backend rejects a write. [message] is safe to show.
class BackendException implements Exception {
  BackendException(this.message, {this.statusCode, this.isRateLimit = false});
  final String message;
  final int? statusCode;
  final bool isRateLimit;
  @override
  String toString() => 'BackendException($statusCode): $message';
}

/// Public vote tallies for one cheat on one platform.
class CheatTally {
  const CheatTally({required this.cheatId, required this.platform, this.works = 0, this.fails = 0});
  final String cheatId;
  final GamePlatform platform;
  final int works;
  final int fails;
}

/// Talks to Supabase over PostgREST.
///
/// Plain REST rather than the `supabase_flutter` package: the app needs four
/// calls and no auth, realtime or storage, so a dependency carrying all of that
/// is not worth it.
///
/// Identity is an anonymous device uuid sent as `x-device-id`. The row-level
/// security policies read that header, so a device can only ever touch its own
/// votes, submissions and reports.
class BackendClient {
  BackendClient({
    required this.config,
    required this.deviceId,
    http.Client? client,
    this.timeout = const Duration(seconds: 12),
  }) : _client = client ?? http.Client();

  final BackendConfig config;

  /// Random uuid generated on first run and stored on the device.
  final String deviceId;
  final Duration timeout;
  final http.Client _client;

  bool get isConfigured => config.hasBackend;

  Map<String, String> get _headers => {
        'apikey': config.supabaseAnonKey!,
        'Authorization': 'Bearer ${config.supabaseAnonKey!}',
        'Content-Type': 'application/json',
        'x-device-id': deviceId,
      };

  Uri _rest(String path, [Map<String, String>? query]) =>
      Uri.parse('${config.supabaseUrl}/rest/v1/$path').replace(queryParameters: query);

  void _requireBackend() {
    if (!isConfigured) {
      throw BackendException('The backend is not configured in this build.');
    }
  }

  /// Registers the device so its rows have a parent to reference. Idempotent:
  /// a conflict means it already exists, which is success.
  Future<void> registerDevice() async {
    _requireBackend();
    final response = await _client
        .post(
          _rest('devices'),
          headers: {..._headers, 'Prefer': 'resolution=ignore-duplicates,return=minimal'},
          body: jsonEncode({'id': deviceId}),
        )
        .timeout(timeout);
    if (response.statusCode >= 400 && response.statusCode != 409) {
      throw _error(response, 'Could not register this device.');
    }
  }

  /// Casts or clears a vote. [value] is 1 for "works", -1 for "does not work",
  /// and 0 to withdraw a previous vote.
  Future<void> vote({
    required String cheatId,
    required GamePlatform platform,
    required int value,
  }) async {
    _requireBackend();
    assert(value == 1 || value == -1 || value == 0);

    if (value == 0) {
      final response = await _client
          .delete(
            _rest('votes', {
              'device_id': 'eq.$deviceId',
              'cheat_id': 'eq.$cheatId',
              'platform': 'eq.${platform.name}',
            }),
            headers: _headers,
          )
          .timeout(timeout);
      if (response.statusCode >= 400) throw _error(response, 'Could not clear your vote.');
      return;
    }

    final response = await _client
        .post(
          _rest('votes'),
          // Upsert: changing your mind replaces the vote rather than failing on
          // the (device, cheat, platform) primary key.
          headers: {..._headers, 'Prefer': 'resolution=merge-duplicates,return=minimal'},
          body: jsonEncode({
            'device_id': deviceId,
            'cheat_id': cheatId,
            'platform': platform.name,
            'value': value,
          }),
        )
        .timeout(timeout);
    if (response.statusCode >= 400) throw _error(response, 'Could not record your vote.');
  }

  /// Public works/fails counts. Votes themselves stay private; this reads the
  /// `cheat_tallies` aggregate function.
  Future<List<CheatTally>> tallies({List<String>? cheatIds}) async {
    _requireBackend();
    final response = await _client
        .post(
          Uri.parse('${config.supabaseUrl}/rest/v1/rpc/cheat_tallies'),
          headers: _headers,
          body: jsonEncode({'cheat_ids': cheatIds}),
        )
        .timeout(timeout);
    if (response.statusCode >= 400) throw _error(response, 'Could not load vote counts.');

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is! List) return const [];
    final platforms = {for (final p in GamePlatform.values) p.name: p};
    return [
      for (final row in decoded)
        if (row is Map && row['cheat_id'] is String && platforms[row['platform']] != null)
          CheatTally(
            cheatId: row['cheat_id'] as String,
            platform: platforms[row['platform']]!,
            works: (row['works'] as num?)?.toInt() ?? 0,
            fails: (row['fails'] as num?)?.toInt() ?? 0,
          ),
    ];
  }

  /// Sends a community cheat submission to the moderation queue. Returns its id
  /// so the app can show "submission received".
  Future<String> submitCheat({
    required String title,
    required CheatCategory category,
    required GamePlatform platform,
    required List<String> sequence,
    String? summary,
    String? sourceNote,
  }) async {
    _requireBackend();
    final response = await _client
        .post(
          _rest('submissions'),
          headers: {..._headers, 'Prefer': 'return=representation'},
          body: jsonEncode({
            'device_id': deviceId,
            'title': title.trim(),
            'category': category.name,
            'platform': platform.name,
            'sequence': sequence,
            if (summary != null && summary.trim().isNotEmpty) 'summary': summary.trim(),
            if (sourceNote != null && sourceNote.trim().isNotEmpty) 'source_note': sourceNote.trim(),
          }),
        )
        .timeout(timeout);
    if (response.statusCode >= 400) throw _error(response, 'Could not send your submission.');

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is List && decoded.isNotEmpty && decoded.first is Map) {
      return (decoded.first as Map)['id'] as String? ?? '';
    }
    return '';
  }

  /// Reports a cheat as wrong or no longer working.
  Future<void> reportCheat({
    required String cheatId,
    required String reason,
    GamePlatform? platform,
    String? gameBuild,
  }) async {
    _requireBackend();
    final response = await _client
        .post(
          _rest('reports'),
          headers: {..._headers, 'Prefer': 'return=minimal'},
          body: jsonEncode({
            'device_id': deviceId,
            'cheat_id': cheatId,
            'reason': reason.trim(),
            if (platform != null) 'platform': platform.name,
            if (gameBuild != null && gameBuild.isNotEmpty) 'game_build': gameBuild,
          }),
        )
        .timeout(timeout);
    // The unique index on pending reports makes a repeat report a no-op.
    if (response.statusCode == 409) return;
    if (response.statusCode >= 400) throw _error(response, 'Could not send your report.');
  }

  BackendException _error(http.Response response, String fallback) {
    String message = fallback;
    bool rateLimited = false;
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));
      if (body is Map) {
        final detail = (body['message'] ?? body['error'] ?? body['hint'])?.toString();
        if (detail != null && detail.isNotEmpty) {
          rateLimited = detail.contains('rate limit');
          // Database messages are written to be user-readable; anything else
          // stays behind the generic fallback.
          if (rateLimited) message = detail;
        }
      }
    } catch (_) {
      // Non-JSON error body; keep the fallback.
    }
    return BackendException(message, statusCode: response.statusCode, isRateLimit: rateLimited);
  }

  void dispose() => _client.close();
}

/// A random v4 uuid for the anonymous device identity. Uses [Random.secure] so
/// ids are not guessable from one another.
String newDeviceId() {
  final rng = Random.secure();
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant 1
  String hex(int start, int end) =>
      bytes.sublist(start, end).map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}
