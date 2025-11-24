import 'package:flutter/material.dart';
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

    final semantics = SemanticsTester(tester);
    final tooltip = MaterialLocalizations.of(
            tester.element(find.byType(RoundedBackButton)))
        .backButtonTooltip;

    final nodes = semantics.nodesWith(label: tooltip);
    expect(nodes, isNotEmpty);
    expect(nodes.first.hasFlag(SemanticsFlag.isButton), isTrue);
    semantics.dispose();
  });
}
