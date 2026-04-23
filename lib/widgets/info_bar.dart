import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class InfoBar extends StatelessWidget {
  const InfoBar({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final fileInfo = appState.fileInfo;

    return MouseRegion(
      cursor: appState.isLoadingFile ? SystemMouseCursors.basic : SystemMouseCursors.click,
      child: GestureDetector(
      onTap: appState.isLoadingFile
          ? null
          : () {
              final ffprobePath =
                  context.read<SettingsProvider>().effectiveFfprobePath;
              appState.pickFile(ffprobePath);
            },
      child: Container(
        height: 44,
        color: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            if (appState.isLoadingFile)
              const _InfoChip(
                icon: Icons.hourglass_empty,
                text: 'Loading...',
              )
            else if (fileInfo == null) ...[
              Icon(Icons.folder_open, size: 14, color: AppTheme.textSecondary),
              const SizedBox(width: 8),
              Text(
                appState.fileError != null
                    ? 'Error: ${appState.fileError}'
                    : 'Click to open a video file',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
              ),
            ] else ...[
              Icon(Icons.movie_outlined, size: 14, color: AppTheme.accent),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  fileInfo.filename,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _divider(),
              _InfoChip(icon: Icons.timer_outlined, text: fileInfo.durationDisplay),
              _divider(),
              _InfoChip(icon: Icons.storage_outlined, text: fileInfo.fileSizeDisplay),
              _divider(),
              _InfoChip(icon: Icons.videocam_outlined, text: fileInfo.videoCodecDisplay),
              _divider(),
              _InfoChip(icon: Icons.crop_outlined, text: fileInfo.resolution),
              _divider(),
              _InfoChip(icon: Icons.graphic_eq, text: fileInfo.audioBitrateDisplay),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 20,
        color: AppTheme.surfaceVariant,
        margin: const EdgeInsets.symmetric(horizontal: 12),
      );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
