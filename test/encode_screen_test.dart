import 'package:cramp4/providers/app_state_provider.dart';
import 'package:cramp4/providers/encoding_provider.dart';
import 'package:cramp4/providers/settings_provider.dart';
import 'package:cramp4/screens/encode_screen.dart';
import 'package:cramp4/widgets/process_queue_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  double queueBoxHeight(WidgetTester tester) {
    final box = tester.widget<SizedBox>(
      find
          .ancestor(of: find.byType(ProcessQueueCard), matching: find.byType(SizedBox))
          .first,
    );
    return box.height!;
  }

  Future<SettingsProvider> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final settings = SettingsProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider(create: (_) => AppStateProvider()),
          ChangeNotifierProvider(create: (_) => EncodingProvider()),
        ],
        child: const MaterialApp(home: Scaffold(body: EncodeScreen())),
      ),
    );
    return settings;
  }

  Future<void> dragHandle(WidgetTester tester, double dy) async {
    final gesture = await tester
        .startGesture(tester.getCenter(find.byKey(const Key('queueResizeHandle'))));
    await gesture.moveBy(Offset(0, dy));
    await tester.pump();
    await gesture.up();
    await tester.pump();
  }

  testWidgets('starts at the persisted default height', (tester) async {
    await pumpScreen(tester);
    expect(queueBoxHeight(tester), 220);
  });

  testWidgets('dragging the handle up grows the queue', (tester) async {
    await pumpScreen(tester);
    await dragHandle(tester, -50);
    expect(queueBoxHeight(tester), 270);
  });

  testWidgets('dragging the handle down shrinks the queue', (tester) async {
    await pumpScreen(tester);
    await dragHandle(tester, 40);
    expect(queueBoxHeight(tester), 180);
  });

  testWidgets('clamps to the minimum height', (tester) async {
    await pumpScreen(tester);
    await dragHandle(tester, 1000);
    expect(queueBoxHeight(tester), 140);
  });

  testWidgets('accumulates multiple updates within a single frame', (tester) async {
    await pumpScreen(tester);
    // No pump between moves: mimics several mouse-move events arriving before
    // the next frame, which must add up rather than overwrite each other.
    final gesture = await tester
        .startGesture(tester.getCenter(find.byKey(const Key('queueResizeHandle'))));
    await gesture.moveBy(const Offset(0, -20));
    await gesture.moveBy(const Offset(0, -20));
    await gesture.moveBy(const Offset(0, -20));
    await gesture.up();
    await tester.pump();
    expect(queueBoxHeight(tester), 280);
  });

  testWidgets('persists the height on drag end', (tester) async {
    final settings = await pumpScreen(tester);
    await dragHandle(tester, -30);
    expect(settings.queueHeight, 250);
  });
}
