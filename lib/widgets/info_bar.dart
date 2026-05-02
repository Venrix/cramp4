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
    final ffprobePath = context.read<SettingsProvider>().effectiveFfprobePath;

    return Container(
      height: 44,
      color: AppTheme.surface,
      child: Row(
        children: [
          // Tappable file info area
          Expanded(
            child: MouseRegion(
              cursor: appState.isLoadingFile
                  ? SystemMouseCursors.basic
                  : SystemMouseCursors.click,
              child: GestureDetector(
                onTap: appState.isLoadingFile
                    ? null
                    : () => appState.pickFile(ffprobePath),
                child: Container(
                  padding: const EdgeInsets.only(left: 16, right: 12),
                  child: Row(
                    children: [
                      if (appState.isLoadingFile)
                        const _InfoChip(
                          icon: Icons.hourglass_empty,
                          text: 'Loading...',
                        )
                      else if (fileInfo == null) ...[
                        const SizedBox(width: 2),
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
            ),
          ),
          // Navigation arrows — only when folder loaded
          if (appState.hasFolderLoaded) ...[
            _navButton(
              icon: Icons.chevron_left,
              enabled: appState.folderIndex > 0 && !appState.isLoadingFile,
              onTap: () => appState.navigateFolderPrev(ffprobePath),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                '${appState.folderIndex + 1} / ${appState.folderTotal}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
            _navButton(
              icon: Icons.chevron_right,
              enabled: appState.folderIndex < appState.folderTotal - 1 && !appState.isLoadingFile,
              onTap: () => appState.navigateFolderNext(ffprobePath),
            ),
            const SizedBox(width: 4),
          ],
          // Folder picker button — always visible
          _FolderButton(enabled: !appState.isLoadingFile),
        ],
      ),
    );
  }

  Widget _navButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) =>
      MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 28,
            height: 44,
            child: Icon(
              icon,
              size: 16,
              color: enabled
                  ? AppTheme.textPrimary
                  : AppTheme.textSecondary.withAlpha(60),
            ),
          ),
        ),
      );

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

class _FolderButton extends StatefulWidget {
  final bool enabled;
  const _FolderButton({required this.enabled});

  @override
  State<_FolderButton> createState() => _FolderButtonState();
}

class _FolderButtonState extends State<_FolderButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.enabled
            ? () {
                final appState = context.read<AppStateProvider>();
                final settings = context.read<SettingsProvider>();
                appState.pickFolder(
                  settings.effectiveFfprobePath,
                  sortField: settings.folderSortField,
                  sortDirection: settings.folderSortDirection,
                  blacklistPattern: settings.blacklistPattern,
                );
              }
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          width: 44,
          height: 44,
          color: _hovered
              ? AppTheme.surfaceVariant.withAlpha(180)
              : Colors.transparent,
          child: Icon(
            Icons.folder_open_outlined,
            size: 16,
            color: _hovered ? AppTheme.accent : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
