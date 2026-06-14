import 'package:cramp4/models/encode_job.dart';
import 'package:cramp4/providers/encoding_provider.dart';
import 'package:cramp4/widgets/process_queue_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class FakeEncoding extends EncodingProvider {
  EncodeJob? _job;
  FakeEncoding(this._job);

  @override
  EncodeJob? get currentJob => _job;

  void setJob(EncodeJob job) {
    _job = job;
    notifyListeners();
  }
}

void main() {
  EncodeJob jobWithLines(int count) => EncodeJob(
        inputPath: 'in.mp4',
        outputPath: 'out.mp4',
        status: JobStatus.encoding,
        startedAt: DateTime(2020),
        logLines: List.generate(count, (i) => 'log line $i'),
      );

  Future<FakeEncoding> pumpCard(WidgetTester tester, EncodeJob job) async {
    final encoding = FakeEncoding(job);
    await tester.pumpWidget(
      ChangeNotifierProvider<EncodingProvider>.value(
        value: encoding,
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(height: 220, child: const ProcessQueueCard()),
          ),
        ),
      ),
    );
    return encoding;
  }

  ScrollPosition scrollPosition(WidgetTester tester) =>
      tester.state<ScrollableState>(find.byType(Scrollable)).position;

  testWidgets('log is wrapped in a SelectionArea for copying', (tester) async {
    await pumpCard(tester, jobWithLines(50));
    expect(find.byType(SelectionArea), findsOneWidget);
  });

  testWidgets('auto-scrolls to the bottom while pinned', (tester) async {
    await pumpCard(tester, jobWithLines(100));
    await tester.pumpAndSettle();
    final pos = scrollPosition(tester);
    expect(pos.pixels, pos.maxScrollExtent);
  });

  testWidgets('stops auto-scrolling after the user scrolls up', (tester) async {
    final encoding = await pumpCard(tester, jobWithLines(100));
    await tester.pumpAndSettle();

    // User scrolls to the top to read/select earlier output.
    scrollPosition(tester).jumpTo(0);
    await tester.pump();

    // New log output arrives.
    encoding.setJob(jobWithLines(120));
    await tester.pumpAndSettle();

    expect(scrollPosition(tester).pixels, 0);
  });

  testWidgets('resumes auto-scroll once back at the bottom', (tester) async {
    final encoding = await pumpCard(tester, jobWithLines(100));
    await tester.pumpAndSettle();

    scrollPosition(tester).jumpTo(0);
    await tester.pump();

    // Return to the bottom, then more output arrives.
    scrollPosition(tester).jumpTo(scrollPosition(tester).maxScrollExtent);
    await tester.pump();
    encoding.setJob(jobWithLines(140));
    await tester.pumpAndSettle();

    final pos = scrollPosition(tester);
    expect(pos.pixels, pos.maxScrollExtent);
  });
}
