import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/encode_settings.dart';
import '../providers/app_state_provider.dart';
import '../theme/app_theme.dart';
import 'full_width_dropdown.dart';

class AudioSettingsCard extends StatelessWidget {
  const AudioSettingsCard({super.key});

  static const _bitrateOptions = [320, 256, 192, 128, 96, 64, 32];

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final settings = appState.settings;
    final audioOn = settings.audioEnabled;

    final fileInfo = appState.fileInfo;
    final originalFormat = audioFormatFromFfprobe(fileInfo?.audioCodec);
    final originalBitrate = nearestAudioBitrate(
        (fileInfo?.audioBitrate ?? 0) ~/ 1000);

    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.music_note_outlined, size: 26, color: AppTheme.accent),
                const SizedBox(width: 8),
                const Text(
                  'Audio Settings',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Text(
                  'AUDIO',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, letterSpacing: 0.8),
                ),
                const SizedBox(width: 8),
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: audioOn,
                    onChanged: appState.setAudioEnabled,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            IgnorePointer(
              ignoring: !audioOn,
              child: AnimatedOpacity(
                opacity: audioOn ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('AUDIO FORMAT'),
                    const SizedBox(height: 6),
                    FullWidthDropdown<AudioFormat>(
                      value: settings.audioFormat,
                      items: AudioFormat.values,
                      labelOf: (v) => v.displayName,
                      onChanged: (v) => appState.setAudioFormat(v!),
                      originalValue: originalFormat,
                    ),
                    if (settings.audioFormat != AudioFormat.copy &&
                        settings.audioFormat != AudioFormat.flac) ...[
                      const SizedBox(height: 14),
                      _fieldLabel('AUDIO BITRATE'),
                      const SizedBox(height: 6),
                      FullWidthDropdown<int>(
                        value: settings.audioBitrateKbps,
                        items: _bitrateOptions,
                        labelOf: (v) => '${v}k',
                        onChanged: (v) => appState.setAudioBitrateKbps(v!),
                        originalValue: originalBitrate,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
      );
}
