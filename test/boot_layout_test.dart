import 'package:bright_horizon/src/screens/boot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('landscape loading bar stays on the screen center', (tester) async {
    tester.view.physicalSize = const Size(900, 400);
    tester.view.devicePixelRatio = 1;
    tester.view.viewPadding = const FakeViewPadding(left: 80, top: 0, right: 0, bottom: 24);
    tester.view.padding = const FakeViewPadding(left: 80, top: 0, right: 0, bottom: 24);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(const MaterialApp(home: BootPage()));
    await tester.pump();

    final bar = tester.getRect(find.byType(LinearProgressIndicator));
    expect(bar.center.dx, closeTo(450, 1));
    expect(bar.left, greaterThan(80));

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 1700));
  });
}
