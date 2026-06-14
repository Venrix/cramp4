import 'package:flutter/material.dart';

import '../widgets/audio_settings_card.dart';
import '../widgets/process_queue_card.dart';
import '../widgets/video_settings_card.dart';

class EncodeScreen extends StatelessWidget {
  const EncodeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
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
        SizedBox(
          height: 220,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: const ProcessQueueCard(),
          ),
        ),
      ],
    );
  }
}
