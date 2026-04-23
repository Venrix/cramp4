import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';

class DropZone extends StatefulWidget {
  final Widget child;

  const DropZone({super.key, required this.child});

  @override
  State<DropZone> createState() => _DropZoneState();
}

class _DropZoneState extends State<DropZone> {
  bool _dragging = false;

  @override
  Widget build(BuildContext context) {
    return DropTarget(
      onDragEntered: (_) => setState(() => _dragging = true),
      onDragExited: (_) => setState(() => _dragging = false),
      onDragDone: (details) {
        setState(() => _dragging = false);
        final files = details.files;
        if (files.isEmpty) return;
        final path = files.first.path;
        final appState = context.read<AppStateProvider>();
        final ffprobePath =
            context.read<SettingsProvider>().effectiveFfprobePath;
        appState.loadFile(path, ffprobePath);
      },
      child: Stack(
        children: [
          widget.child,
          if (_dragging)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.background.withAlpha(220),
                  border: Border.all(color: AppTheme.accent, width: 2),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.file_download_outlined,
                        size: 56,
                        color: AppTheme.accent,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Drop file here',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
