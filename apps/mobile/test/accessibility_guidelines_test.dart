import 'package:flutter_test/flutter_test.dart';
import 'package:mediflow_mobile/main.dart';

void main() {
  testWidgets('meets Android accessibility guidelines', (tester) async {
    final semanticsHandle = tester.ensureSemantics();

    try {
      await tester.pumpWidget(const MainApp());

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));

      await expectLater(tester, meetsGuideline(textContrastGuideline));
    } finally {
      semanticsHandle.dispose();
    }
  });
}
