import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tool_box_mobile/src/shell/shell_scope.dart';

void main() {
  testWidgets('ShellScope exposes openDrawer to descendants', (tester) async {
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: ShellScope(
          openDrawer: () => opened = true,
          child: Builder(
            builder: (context) => TextButton(
              onPressed: ShellScope.maybeOf(context)!.openDrawer,
              child: const Text('menu'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('menu'));
    expect(opened, isTrue);
  });
}
