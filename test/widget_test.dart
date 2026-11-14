import 'package:flutter_test/flutter_test.dart';

import 'package:vicedex/main.dart';

import 'support/test_pack.dart';

void main() {
  testWidgets('Cheat Library loads and opens the finder', (tester) async {
    final state = await loadedState();
    addTearDown(state.dispose);

    await tester.pumpWidget(ViceDexApp(useGoogleFonts: false, state: state));
    await tester.pumpAndSettle();

    expect(find.text('Cheat Library'), findsOneWidget);
    expect(find.text('Spawn Helicopter'), findsWidgets);

    await tester.tap(find.byTooltip('Quick cheat finder'));
    await tester.pumpAndSettle();
    expect(find.text('Quick Cheat Finder'), findsOneWidget);
  });
}
