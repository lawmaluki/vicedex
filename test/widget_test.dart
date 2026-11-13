import 'package:flutter_test/flutter_test.dart';

import 'package:vicedex/main.dart';

void main() {
  testWidgets('Cheat Library loads and opens the finder', (tester) async {
    await tester.pumpWidget(const ViceDexApp(useGoogleFonts: false));
    await tester.pumpAndSettle();

    expect(find.text('Cheat Library'), findsOneWidget);
    expect(find.text('Spawn Helicopter'), findsWidgets);

    await tester.tap(find.byTooltip('Quick cheat finder'));
    await tester.pumpAndSettle();
    expect(find.text('Quick Cheat Finder'), findsOneWidget);
  });
}
