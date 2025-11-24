import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../widgets/rounded_back_button.dart';

void main() {
  testWidgets('RoundedBackButton announces itself as a button', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: RoundedBackButton()),
        ),
      ),
    );

    final semanticsHandle = tester.ensureSemantics();
    final tooltip = MaterialLocalizations.of(
            tester.element(find.byType(RoundedBackButton)))
        .backButtonTooltip;

    final node = tester.getSemantics(find.byType(RoundedBackButton));

    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(node.label, tooltip);

    semanticsHandle.dispose();
  });
}
