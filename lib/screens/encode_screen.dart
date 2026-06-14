import 'package:flutter/material.dart';

import '../widgets/audio_settings_card.dart';
import '../widgets/process_queue_card.dart';
import '../widgets/video_settings_card.dart';

class EncodeScreen extends StatefulWidget {
  const EncodeScreen({super.key});

  @override
  State<EncodeScreen> createState() => _EncodeScreenState();
}

class _EncodeScreenState extends State<EncodeScreen> {
  // Settings shrink-wrap to content, capped here.
  static const double _maxSettingsHeight = 360;
  // Queue floor; below this the page scrolls instead.
  static const double _minQueueHeight = 220;

  final GlobalKey _settingsKey = GlobalKey();
  double _settingsHeight = 0;

  // Measure settings so the queue gets an explicit height (its inner ListView
  // rules out Expanded and SliverFillRemaining).
  void _measureSettings() {
    final box = _settingsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if ((box.size.height - _settingsHeight).abs() > 0.5) {
      setState(() => _settingsHeight = box.size.height);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureSettings());

    return LayoutBuilder(
      builder: (context, constraints) {
        // Queue fills the leftover space, but never below its min.
        final queueHeight = (constraints.maxHeight - _settingsHeight)
            .clamp(_minQueueHeight, double.infinity)
            .toDouble();

        return SingleChildScrollView(
          child: Column(
            children: [
              _SettingsPanels(key: _settingsKey, maxHeight: _maxSettingsHeight),
              SizedBox(height: queueHeight, child: const _QueuePanel()),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsPanels extends StatelessWidget {
  // Cap the shrink-wrapped settings; content taller than this scrolls inside.
  final double maxHeight;

  const _SettingsPanels({super.key, required this.maxHeight});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        // Both cards match the taller one's height.
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: const [
              Expanded(child: VideoSettingsCard()),
              SizedBox(width: 12),
              Expanded(child: AudioSettingsCard()),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueuePanel extends StatelessWidget {
  const _QueuePanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: ProcessQueueCard(),
    );
  }
}
