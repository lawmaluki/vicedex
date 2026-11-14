import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vicedex/data/backend_client.dart';
import 'package:vicedex/data/backend_config.dart';
import 'package:vicedex/models/models.dart';

void main() {
  const config = BackendConfig(
    supabaseUrl: 'https://proj.supabase.co',
    supabaseAnonKey: 'anon-key',
  );
  const deviceId = '11111111-2222-4333-8444-555555555555';

  BackendClient clientWith(MockClient mock) =>
      BackendClient(config: config, deviceId: deviceId, client: mock);

  test('newDeviceId produces a well-formed v4 uuid', () {
    final id = newDeviceId();
    expect(
      id,
      matches(RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$')),
    );
    expect(newDeviceId(), isNot(id));
  });

  test('every request carries the key and the device identity', () async {
    http.Request? seen;
    final client = clientWith(MockClient((request) async {
      seen = request;
      return http.Response('', 201);
    }));

    await client.vote(cheatId: 'c1', platform: GamePlatform.ps5, value: 1);

    expect(seen!.headers['apikey'], 'anon-key');
    expect(seen!.headers['Authorization'], 'Bearer anon-key');
    // The row-level security policies read this header; without it a write
    // matches no policy and is rejected.
    expect(seen!.headers['x-device-id'], deviceId);
  });

  test('a vote upserts with the platform in the row', () async {
    http.Request? seen;
    final client = clientWith(MockClient((request) async {
      seen = request;
      return http.Response('', 201);
    }));

    await client.vote(cheatId: 'c1', platform: GamePlatform.xbox, value: -1);

    expect(seen!.method, 'POST');
    expect(seen!.url.path, '/rest/v1/votes');
    expect(seen!.headers['Prefer'], contains('merge-duplicates'));
    expect(jsonDecode(seen!.body), {
      'device_id': deviceId,
      'cheat_id': 'c1',
      'platform': 'xbox',
      'value': -1,
    });
  });

  test('withdrawing a vote deletes just that row', () async {
    http.Request? seen;
    final client = clientWith(MockClient((request) async {
      seen = request;
      return http.Response('', 204);
    }));

    await client.vote(cheatId: 'c1', platform: GamePlatform.ps5, value: 0);

    expect(seen!.method, 'DELETE');
    expect(seen!.url.queryParameters, {
      'device_id': 'eq.$deviceId',
      'cheat_id': 'eq.c1',
      'platform': 'eq.ps5',
    });
  });

  test('tallies decode into per-platform counts', () async {
    final client = clientWith(MockClient((_) async => http.Response(
          jsonEncode([
            {'cheat_id': 'c1', 'platform': 'ps5', 'works': 12, 'fails': 2},
            {'cheat_id': 'c1', 'platform': 'xbox', 'works': 3, 'fails': 0},
            {'cheat_id': 'c2', 'platform': 'nope', 'works': 9, 'fails': 9},
          ]),
          200,
        )));

    final rows = await client.tallies(cheatIds: ['c1', 'c2']);

    // The unknown platform is dropped rather than guessed at.
    expect(rows, hasLength(2));
    expect(rows.first.works, 12);
    expect(rows.first.platform, GamePlatform.ps5);
  });

  test('a rate limit comes back as a message worth showing', () async {
    final client = clientWith(MockClient((_) async => http.Response(
          jsonEncode({'message': 'submission rate limit reached: try again later'}),
          400,
        )));

    await expectLater(
      client.submitCheat(
        title: 'Spawn thing',
        category: CheatCategory.vehicles,
        platform: GamePlatform.ps5,
        sequence: const ['○', '○'],
      ),
      throwsA(isA<BackendException>()
          .having((e) => e.isRateLimit, 'isRateLimit', isTrue)
          .having((e) => e.message, 'message', contains('rate limit'))),
    );
  });

  test('an internal database error is not shown to the user verbatim', () async {
    final client = clientWith(MockClient((_) async => http.Response(
          jsonEncode({'message': 'null value in column "device_id" violates not-null'}),
          400,
        )));

    await expectLater(
      client.reportCheat(cheatId: 'c1', reason: 'broken'),
      throwsA(isA<BackendException>()
          .having((e) => e.message, 'message', 'Could not send your report.')),
    );
  });

  test('a duplicate pending report is treated as already filed', () async {
    final client = clientWith(MockClient((_) async => http.Response('', 409)));
    // The unique index on pending reports makes this a no-op, not an error.
    await client.reportCheat(cheatId: 'c1', reason: 'broken');
  });

  test('registering an existing device is not an error', () async {
    final client = clientWith(MockClient((_) async => http.Response('', 409)));
    await client.registerDevice();
  });

  test('an unconfigured backend refuses writes instead of calling out', () async {
    var called = false;
    final client = BackendClient(
      config: const BackendConfig(),
      deviceId: deviceId,
      client: MockClient((_) async {
        called = true;
        return http.Response('', 200);
      }),
    );

    await expectLater(
      client.vote(cheatId: 'c1', platform: GamePlatform.ps5, value: 1),
      throwsA(isA<BackendException>()),
    );
    expect(called, isFalse);
  });

  test('submission sends the sequence and trims free text', () async {
    http.Request? seen;
    final client = clientWith(MockClient((request) async {
      seen = request;
      return http.Response(jsonEncode([{'id': 'sub-1'}]), 201);
    }));

    final id = await client.submitCheat(
      title: '  Spawn Helicopter  ',
      category: CheatCategory.vehicles,
      platform: GamePlatform.ps5,
      sequence: const ['○', '△', 'L1'],
      summary: '   ',
      sourceNote: ' tested twice ',
    );

    final body = jsonDecode(seen!.body) as Map;
    expect(id, 'sub-1');
    expect(body['title'], 'Spawn Helicopter');
    expect(body['sequence'], ['○', '△', 'L1']);
    expect(body['source_note'], 'tested twice');
    // A blank summary is omitted rather than stored as whitespace.
    expect(body.containsKey('summary'), isFalse);
  });
}
