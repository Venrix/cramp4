import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class TrimTimeline extends StatelessWidget {
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

  Duration _seekFromDx(double dx, double width) {
    if (width == 0 || total.inMilliseconds == 0) return Duration.zero;
    final fraction = dx.clamp(0.0, width) / width;
    return Duration(milliseconds: (fraction * total.inMilliseconds).round());
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => onSeek(_seekFromDx(d.localPosition.dx, w)),
              onHorizontalDragStart: (d) =>
                  onSeek(_seekFromDx(d.localPosition.dx, w)),
              onHorizontalDragUpdate: (d) =>
                  onSeek(_seekFromDx(d.localPosition.dx, w)),
              child: CustomPaint(
                painter: _TrimTimelinePainter(
                  total: total,
                  start: start,
                  end: end,
                  position: position,
                ),
                size: Size(w, 48),
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
