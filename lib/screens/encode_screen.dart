import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_settings_card.dart';
import '../widgets/process_queue_card.dart';
import '../widgets/video_settings_card.dart';

class EncodeScreen extends StatefulWidget {
  const EncodeScreen({super.key});

  @override
  State<EncodeScreen> createState() => _EncodeScreenState();
}

class _EncodeScreenState extends State<EncodeScreen> {
  static const double _minQueueHeight = 140;
  static const double _minSettingsHeight = 200;

  // Live drag value. Null until the user drags, so the persisted height is
  // used on first build.
  double? _queueHeight;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxQueueHeight =
            (constraints.maxHeight - _minSettingsHeight).clamp(_minQueueHeight, double.infinity);
        final height = (_queueHeight ?? settings.queueHeight)
            .clamp(_minQueueHeight, maxQueueHeight);

        return Column(
          children: [
            Expanded(
              child: Padding(
                // Bottom gap is owned by the resize handle so its grip can sit
                // centered in the seam between the cards.
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
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
            _ResizeHandle(
              // Accumulate from the live field, not the build-time `height`:
              // mouse-move events outpace frames, so several updates land per
              // frame and must add up rather than each recompute from a stale base.
              onDragUpdate: (dy) {
                setState(() {
                  final base = _queueHeight ?? settings.queueHeight;
                  _queueHeight =
                      (base - dy).clamp(_minQueueHeight, maxQueueHeight);
                });
              },
              onDragEnd: () {
                if (_queueHeight != null) settings.setQueueHeight(_queueHeight!);
              },
            ),
            SizedBox(
              height: height,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: const ProcessQueueCard(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ResizeHandle extends StatefulWidget {
  final ValueChanged<double> onDragUpdate;
  final VoidCallback onDragEnd;

  const _ResizeHandle({required this.onDragUpdate, required this.onDragEnd});

  @override
  State<_ResizeHandle> createState() => _ResizeHandleState();
}

class _ResizeHandleState extends State<_ResizeHandle> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeUpDown,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        key: const Key('queueResizeHandle'),
        behavior: HitTestBehavior.opaque,
        onVerticalDragUpdate: (details) => widget.onDragUpdate(details.delta.dy),
        onVerticalDragEnd: (_) => widget.onDragEnd(),
        child: Container(
          height: 20,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _hovered ? AppTheme.accent : AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}
