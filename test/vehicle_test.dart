import 'package:flutter_test/flutter_test.dart';

import 'package:vicedex/main.dart';
import 'package:vicedex/models/models.dart';
import 'package:vicedex/utils/format.dart';

Vehicle _car(String id, double? speed, [VehicleClass c = VehicleClass.cars]) => Vehicle(
      id: id,
      name: id,
      vehicleClass: c,
      status: VerificationStatus.rumour,
      specs: VehicleSpecs(topSpeedMph: speed),
    );

void main() {
  group('speedRankInClass', () {
    final fast = _car('fast', 130);
    final mid = _car('mid', 110);
    final slow = _car('slow', 90);
    final unmeasured = _car('unmeasured', null);
    final bike = _car('bike', 200, VehicleClass.bikes);
    final all = [fast, mid, slow, unmeasured, bike];

    test('ranks within class, ignoring other classes and unmeasured peers', () {
      expect(speedRankInClass(fast, all), (position: 1, total: 3));
      expect(speedRankInClass(slow, all), (position: 3, total: 3));
      expect(speedRankInClass(bike, all), (position: 1, total: 1));
    });

    test('is null without a measured top speed', () {
      expect(speedRankInClass(unmeasured, all), isNull);
    });

    test('ties share the higher place', () {
      final twin = _car('twin', 130);
      expect(speedRankInClass(twin, [...all, twin]), (position: 1, total: 4));
      expect(speedRankInClass(mid, [...all, twin]), (position: 3, total: 4));
    });
  });

  test('ordinal', () {
    expect([1, 2, 3, 4, 11, 12, 13, 21, 22, 101, 111].map(ordinal).toList(),
        ['1st', '2nd', '3rd', '4th', '11th', '12th', '13th', '21st', '22nd', '101st', '111th']);
  });

  test('thousands', () {
    expect(thousands(190), '190');
    expect(thousands(1670), '1,670');
    expect(thousands(1234567), '1,234,567');
  });

  testWidgets('vehicle sheet shows rank, specs, tags and TBD values', (tester) async {
    await tester.pumpWidget(const ViceDexApp(useGoogleFonts: false));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Vehicles'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sample muscle car'));
    await tester.pumpAndSettle();

    expect(find.text('Added in Launch 1.0'), findsOneWidget);
    expect(find.text('Ultimate Edition only'), findsOneWidget);
    expect(find.text('2nd'), findsOneWidget); // 121 > 112.5 > 104.5
    expect(find.text('113 mph'), findsOneWidget);
    expect(find.text('1,680 kg'), findsOneWidget);
    expect(find.text('TBD'), findsWidgets); // no performance ratings yet
  });
}
