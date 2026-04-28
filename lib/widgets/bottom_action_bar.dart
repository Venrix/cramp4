import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../providers/encoding_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class BottomActionBar extends StatelessWidget {
  const BottomActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final encoding = context.watch<EncodingProvider>();

    final canStart = appState.fileInfo != null && !encoding.isEncoding;
    final canAbort = encoding.isEncoding;

    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.surfaceVariant)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton(
            onPressed: canAbort ? encoding.abort : null,
            child: const Text('ABORT'),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: canStart
                ? () {
                    final settings = context.read<SettingsProvider>();
                    final fileInfo = appState.fileInfo!;

                    // Warn if target size too small
                    final targetMB = appState.settings.targetSizeMB;
                    if (targetMB != null && targetMB > 0) {
                      final trimDuration = appState.trimEnd - appState.trimStart;
                      final durationSecs = trimDuration.inMilliseconds > 0
                          ? trimDuration.inMilliseconds / 1000.0
                          : fileInfo.durationSeconds;
                      final audioBitrate = appState.settings.audioEnabled ? appState.settings.audioBitrateKbps : 0;
                      final videoBitrateKbps = ((targetMB * 8 * 1024) / durationSecs) - audioBitrate;
                      if (videoBitrateKbps < 50) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Target size too small for this video duration.'),
                            backgroundColor: AppTheme.statusError,
                          ),
                        );
                        return;
                      }
                    }

                    encoding.startEncoding(
                      fileInfo: fileInfo,
                      settings: appState.settings,
                      settingsConfig: settings,
                      trimStart: appState.trimStart,
                      trimEnd: appState.trimEnd,
                    );
                  }
                : null,
            child: const Text('START ENCODING'),
          ),
        ],
      ),
    );
  }
}
