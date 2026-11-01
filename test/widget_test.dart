import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mxff_ai/app/app.dart';

void main() {
  testWidgets('MXFF AI app builds and shows home', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MxffApp()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('MXFF AI, your assistant'), findsOneWidget);
  });
}
