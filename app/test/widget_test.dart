import 'package:flutter_test/flutter_test.dart';

import 'package:app/main.dart';

void main() {
  testWidgets('abre a tela inicial do VanTrack', (tester) async {
    await tester.pumpWidget(const VanTrackApp());

    expect(find.text('VanTrack'), findsOneWidget);
  });
}