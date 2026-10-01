import 'package:bright_horizon/src/profile.dart';
import 'package:bright_horizon/src/screens/boot.dart';
import 'package:bright_horizon/src/screens/cabinet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

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

  testWidgets('a cheat preset closes itself and lands on the banner', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final profile = Profile();
    await profile.load();
    await tester.pumpWidget(
      ProfileScope(
        profile: profile,
        child: MaterialApp(
          theme: ThemeData(fontFamily: 'Roboto'),
          home: const CabinetPage(),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('cheat-entry')));
    await tester.pumpAndSettle();
    expect(find.text('Mega Win'), findsOneWidget);

    await tester.tap(find.text('Mega Win'));
    await tester.pump();
    expect(find.text('Mega Win'), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('MEGA WIN'), findsOneWidget);
    expect(find.byKey(const Key('cheat-entry')), findsOneWidget);
    expect(profile.credits, greaterThan(Profile.openingCredits));
  });
}
