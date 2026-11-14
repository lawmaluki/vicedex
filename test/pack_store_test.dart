import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vicedex/data/pack_store.dart';

import 'support/test_pack.dart';

void main() {
  String bundledJson({String etag = 'bundled', String generated = '2026-11-01T00:00:00Z'}) =>
      jsonEncode({...testPackJson(), 'etag': etag, 'generatedAt': generated});

  test('serves the bundled pack when no remote is configured', () async {
    final store = PackStore(assetReader: (_) async => bundledJson());
    final result = await store.load();

    expect(result.origin, PackOrigin.bundled);
    expect(result.pack.etag, 'bundled');
    expect(result.error, isNull);
  });

  test('prefers a newer remote pack', () async {
    final store = PackStore(
      remoteUrl: 'https://cdn.test/latest.json',
      assetReader: (_) async => bundledJson(),
      client: MockClient((_) async => http.Response(
            jsonEncode({
              ...testPackJson(),
              'etag': 'fresh',
              'generatedAt': '2026-11-14T00:00:00Z',
            }),
            200,
            headers: {'content-type': 'application/json'},
          )),
    );

    final result = await store.load();
    expect(result.origin, PackOrigin.network);
    expect(result.pack.etag, 'fresh');
  });

  test('keeps the bundled pack when the network fails', () async {
    final store = PackStore(
      remoteUrl: 'https://cdn.test/latest.json',
      assetReader: (_) async => bundledJson(),
      client: MockClient((_) async => throw http.ClientException('offline')),
    );

    final result = await store.load();
    // Offline must be a degraded read, never an empty library.
    expect(result.origin, PackOrigin.bundled);
    expect(result.pack.cheats, isNotEmpty);
    expect(result.error, isNotNull);
  });

  test('a 500 leaves the bundled pack in place', () async {
    final store = PackStore(
      remoteUrl: 'https://cdn.test/latest.json',
      assetReader: (_) async => bundledJson(),
      client: MockClient((_) async => http.Response('upstream exploded', 500)),
    );

    final result = await store.load();
    expect(result.origin, PackOrigin.bundled);
    expect(result.error, isNotNull);
  });

  test('sends If-None-Match and honours a 304', () async {
    final sentHeaders = <String, String>{};
    final store = PackStore(
      remoteUrl: 'https://cdn.test/latest.json',
      assetReader: (_) async => bundledJson(etag: 'abc123'),
      client: MockClient((request) async {
        sentHeaders.addAll(request.headers);
        return http.Response('', 304);
      }),
    );

    final result = await store.load();
    expect(sentHeaders['If-None-Match'], '"abc123"');
    expect(result.origin, PackOrigin.bundled);
    expect(result.error, isNull);
  });

  test('an identical etag does not replace the bundled pack', () async {
    final store = PackStore(
      remoteUrl: 'https://cdn.test/latest.json',
      assetReader: (_) async => bundledJson(etag: 'same'),
      client: MockClient((_) async => http.Response(
            jsonEncode({
              ...testPackJson(),
              'etag': 'same',
              'generatedAt': '2026-11-20T00:00:00Z',
            }),
            200,
          )),
    );

    final result = await store.load();
    expect(result.origin, PackOrigin.bundled);
  });

  test('an older remote pack is ignored', () async {
    final store = PackStore(
      remoteUrl: 'https://cdn.test/latest.json',
      assetReader: (_) async => bundledJson(generated: '2026-11-10T00:00:00Z'),
      client: MockClient((_) async => http.Response(
            jsonEncode({
              ...testPackJson(),
              'etag': 'stale',
              'generatedAt': '2026-01-01T00:00:00Z',
            }),
            200,
          )),
    );

    final result = await store.load();
    expect(result.pack.etag, 'bundled');
  });

  test('a corrupt remote body does not take the app down', () async {
    final store = PackStore(
      remoteUrl: 'https://cdn.test/latest.json',
      assetReader: (_) async => bundledJson(),
      client: MockClient((_) async => http.Response('{ this is not json', 200)),
    );

    final result = await store.load();
    expect(result.origin, PackOrigin.bundled);
    expect(result.error, isNotNull);
  });

  test('reports no usable pack when both sources fail', () async {
    final store = PackStore(
      remoteUrl: 'https://cdn.test/latest.json',
      assetReader: (_) async => throw Exception('asset missing'),
      client: MockClient((_) async => throw http.ClientException('offline')),
    );

    final result = await store.load();
    expect(result.origin, PackOrigin.none);
    expect(result.pack.isEmpty, isTrue);
    expect(result.error, isNotNull);
  });
}
