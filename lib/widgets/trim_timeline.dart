import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class TrimTimeline extends StatefulWidget {
  final Duration total;
  final Duration start;
  final Duration end;
  final Duration position;
  final ValueChanged<Duration> onSeek;

  const TrimTimeline({
    super.key,
    required this.total,
    required this.start,
    required this.end,
    required this.position,
    required this.onSeek,
  });

  @override
  State<TrimTimeline> createState() => _TrimTimelineState();
}

class _TrimTimelineState extends State<TrimTimeline> {
  bool _focused = false;

  static const _seekStepMs = 5000;
  static const _seekStepLargeMs = 15000;

  Duration _seekFromDx(double dx, double width) {
    if (width == 0 || widget.total.inMilliseconds == 0) return Duration.zero;
    final fraction = dx.clamp(0.0, width) / width;
    return Duration(
        milliseconds: (fraction * widget.total.inMilliseconds).round());
  }

  void _seekRelative(int deltaMs) {
    final newMs = (widget.position.inMilliseconds + deltaMs)
        .clamp(0, widget.total.inMilliseconds);
    widget.onSeek(Duration(milliseconds: newMs));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Focus(
            onFocusChange: (f) => setState(() => _focused = f),
            onKeyEvent: (node, event) {
              if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                return KeyEventResult.ignored;
              }
              final shift = HardwareKeyboard.instance.isShiftPressed;
              final step = shift ? _seekStepLargeMs : _seekStepMs;
              if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                _seekRelative(-step);
                return KeyEventResult.handled;
              }
              if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                _seekRelative(step);
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _focused ? AppTheme.accent : Colors.transparent,
                  width: 1.5,
                ),
              ),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) =>
                      widget.onSeek(_seekFromDx(d.localPosition.dx, w)),
                  onHorizontalDragStart: (d) =>
                      widget.onSeek(_seekFromDx(d.localPosition.dx, w)),
                  onHorizontalDragUpdate: (d) =>
                      widget.onSeek(_seekFromDx(d.localPosition.dx, w)),
                  child: CustomPaint(
                    painter: _TrimTimelinePainter(
                      total: widget.total,
                      start: widget.start,
                      end: widget.end,
                      position: widget.position,
                    ),
                    size: Size(w, 48),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TrimTimelinePainter extends CustomPainter {
  final Duration total;
  final Duration start;
  final Duration end;
  final Duration position;

  const _TrimTimelinePainter({
    required this.total,
    required this.start,
    required this.end,
    required this.position,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (total.inMilliseconds == 0) return;

    final w = size.width;
    final cy = size.height / 2;
    const trackH = 6.0;
    const markerH = 22.0;
    const posH = 32.0;

    final trackTop = cy - trackH / 2;
    final trackBottom = cy + trackH / 2;

    final totalMs = total.inMilliseconds.toDouble();
    final startX = (start.inMilliseconds / totalMs) * w;
    final endX = (end.inMilliseconds / totalMs) * w;
    final posX = (position.inMilliseconds / totalMs) * w;

    // Background track
    final bgPaint = Paint()..color = AppTheme.surfaceVariant;
    canvas.drawRRect(
      RRect.fromLTRBR(0, trackTop, w, trackBottom, const Radius.circular(3)),
      bgPaint,
    );

    // Trim region
    if (endX > startX) {
      final accentPaint = Paint()..color = AppTheme.accent;
      canvas.drawRect(
        Rect.fromLTRB(startX, trackTop, endX, trackBottom),
        accentPaint,
      );
    }

    // Start marker
    final markerPaint = Paint()
      ..color = AppTheme.accent
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(startX, cy - markerH / 2),
      Offset(startX, cy + markerH / 2),
      markerPaint,
    );

    // End marker
    canvas.drawLine(
      Offset(endX, cy - markerH / 2),
      Offset(endX, cy + markerH / 2),
      markerPaint,
    );

    // Position indicator
    final posPaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(posX, cy - posH / 2),
      Offset(posX, cy + posH / 2),
      posPaint,
    );
  }

  @override
  bool shouldRepaint(_TrimTimelinePainter old) =>
      total != old.total ||
      start != old.start ||
      end != old.end ||
      position != old.position;
}
