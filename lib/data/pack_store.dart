import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'content_pack.dart';
import 'pack_codec.dart';

/// Where a loaded pack came from. Shown in the app's about/debug line so it is
/// obvious whether the user is on fresh or bundled content.
enum PackOrigin { bundled, network, none }

class PackLoad {
  const PackLoad(this.pack, this.origin, {this.error});
  final ContentPack pack;
  final PackOrigin origin;

  /// Set when a network refresh failed but a usable pack was still returned.
  final Object? error;
}

/// Reads the content pack from the app bundle and, when configured, refreshes
/// it over HTTP.
///
/// Offline-first by design: the bundled copy loads immediately so the first
/// frame has content and the app is fully usable on a plane, then a network
/// refresh replaces it if a newer pack exists. A failed refresh is never fatal.
class PackStore {
  PackStore({
    this.remoteUrl,
    http.Client? client,
    this.assetPath = 'assets/content_pack.json',
    this.timeout = const Duration(seconds: 10),
    AssetReader? assetReader,
    this.codec = const PackCodec(),
  })  : _client = client ?? http.Client(),
        _readAsset = assetReader ?? rootBundle.loadString;

  /// Absolute URL of `latest.json`. Null disables network refresh, which is the
  /// default until a host is configured.
  final String? remoteUrl;
  final String assetPath;
  final Duration timeout;
  final PackCodec codec;

  final http.Client _client;
  final AssetReader _readAsset;

  /// Last etag seen from the network, sent as `If-None-Match` so an unchanged
  /// pack costs a 304 instead of a download.
  String? _etag;

  /// Loads the copy shipped inside the app. Throws only if the asset is
  /// missing or unparseable, which is a build error, not a runtime condition.
  Future<ContentPack> loadBundled() async {
    final raw = await _readAsset(assetPath);
    return codec.decode(jsonDecode(raw));
  }

  /// Fetches a newer pack, or null when the server says nothing changed.
  Future<ContentPack?> fetchRemote({String? ifNoneMatch}) async {
    final url = remoteUrl;
    if (url == null) return null;

    final etag = ifNoneMatch ?? _etag;
    final response = await _client
        .get(Uri.parse(url), headers: {
          'Accept': 'application/json',
          if (etag != null && etag.isNotEmpty) 'If-None-Match': '"$etag"',
        })
        .timeout(timeout);

    if (response.statusCode == 304) return null;
    if (response.statusCode != 200) {
      throw http.ClientException('pack fetch failed: HTTP ${response.statusCode}', Uri.parse(url));
    }

    final pack = codec.decode(jsonDecode(utf8.decode(response.bodyBytes)));
    _etag = pack.etag;
    return pack;
  }

  /// Bundled pack first, then a refresh attempt. Returns whichever is newer,
  /// and reports the error alongside the usable pack if the refresh failed.
  Future<PackLoad> load() async {
    ContentPack? bundled;
    Object? bundleError;
    try {
      bundled = await loadBundled();
    } catch (error) {
      bundleError = error;
      if (kDebugMode) debugPrint('ViceDex: bundled pack unreadable: $error');
    }

    if (remoteUrl == null) {
      return bundled != null
          ? PackLoad(bundled, PackOrigin.bundled)
          : PackLoad(ContentPack.empty, PackOrigin.none, error: bundleError);
    }

    try {
      final remote = await fetchRemote(ifNoneMatch: bundled?.etag);
      if (remote != null && _isNewer(remote, bundled)) {
        return PackLoad(remote, PackOrigin.network);
      }
    } catch (error) {
      if (bundled == null) {
        return PackLoad(ContentPack.empty, PackOrigin.none, error: error);
      }
      return PackLoad(bundled, PackOrigin.bundled, error: error);
    }

    return bundled != null
        ? PackLoad(bundled, PackOrigin.bundled)
        : PackLoad(ContentPack.empty, PackOrigin.none, error: bundleError);
  }

  /// Equal etags mean identical records, so a rebuild with no content change
  /// does not churn the UI.
  bool _isNewer(ContentPack remote, ContentPack? local) {
    if (local == null) return true;
    if (remote.etag.isNotEmpty && remote.etag == local.etag) return false;
    return !remote.generatedAt.isBefore(local.generatedAt);
  }

  void dispose() => _client.close();
}

/// Indirection over `rootBundle.loadString` so tests can supply a pack without
/// a Flutter asset bundle.
typedef AssetReader = Future<String> Function(String path);
