import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
          if (appState.isLoadingFile)
            const Padding(
              padding: EdgeInsets.only(left: 16),
              child: _InfoChip(icon: Icons.hourglass_empty, text: 'Loading...'),
            )
          else if (fileInfo == null) ...[
            if (appState.fileError != null)
              Padding(
                padding: const EdgeInsets.only(left: 16),
                child: Text(
                  'Error: ${appState.fileError}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              )
            else ...[
              const SizedBox(width: 8),
              _OpenButton(
                icon: Icons.movie_outlined,
                label: 'Open file',
                onPressed: () => appState.pickFile(ffprobePath),
              ),
              const SizedBox(width: 4),
              _OpenButton(
                icon: Icons.folder_outlined,
                label: 'Open folder',
                onPressed: () {
                  final settings = context.read<SettingsProvider>();
                  appState.pickFolder(
                    ffprobePath,
                    sortField: settings.folderSortField,
                    sortDirection: settings.folderSortDirection,
                    blacklistPattern: settings.blacklistPattern,
                  );
                },
              ),
            ],
          ] else ...[
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 12),
                child: Row(
                  children: [
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
            // Clear button
            _ClearButton(onPressed: appState.clearFile),
          ],
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

class _OpenButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _OpenButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  State<_OpenButton> createState() => _OpenButtonState();
}

class _OpenButtonState extends State<_OpenButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              color: _hovered ? AppTheme.surfaceVariant.withAlpha(180) : Colors.transparent,
              border: Border.all(
                color: _focused
                    ? AppTheme.accent
                    : _hovered
                        ? AppTheme.surfaceVariant
                        : Colors.transparent,
                width: _focused ? 1.5 : 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 14, color: AppTheme.textSecondary),
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ClearButton extends StatefulWidget {
  final VoidCallback onPressed;
  const _ClearButton({required this.onPressed});

  @override
  State<_ClearButton> createState() => _ClearButtonState();
}

class _ClearButtonState extends State<_ClearButton> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onFocusChange: (f) => setState(() => _focused = f),
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.space)) {
          widget.onPressed();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 100),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _hovered
                  ? AppTheme.surfaceVariant.withAlpha(180)
                  : Colors.transparent,
              border: Border.all(
                color: _focused ? AppTheme.accent : Colors.transparent,
                width: _focused ? 1.5 : 1,
              ),
            ),
            child: Icon(
              Icons.close,
              size: 16,
              color: _hovered ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
