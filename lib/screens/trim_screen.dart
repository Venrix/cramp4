import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/trim_timeline.dart';

class TrimScreen extends StatefulWidget {
  const TrimScreen({super.key});

  @override
  State<TrimScreen> createState() => _TrimScreenState();
}

class _TrimScreenState extends State<TrimScreen> {
  late final Player _player;
  late final VideoController _controller;
  late final FocusNode _focusNode;
  String? _loadedPath;
  Duration _position = Duration.zero;
  bool _isPlaying = false;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<bool>? _playingSub;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _player = Player();
    _controller = VideoController(_player);
    _positionSub = _player.stream.position.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _playingSub = _player.stream.playing.listen((playing) {
      if (mounted) setState(() => _isPlaying = playing);
    });
    HardwareKeyboard.instance.addHandler(_handleGlobalKey);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final fileInfo = context.read<AppStateProvider>().fileInfo;
    if (fileInfo?.path != _loadedPath) {
      _loadedPath = fileInfo?.path;
      _position = Duration.zero;
      if (fileInfo != null) _loadVideo(fileInfo.path);
    }
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKey);
    _focusNode.dispose();
    _positionSub?.cancel();
    _playingSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  bool _handleGlobalKey(KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;
    // Only when trim tab is active
    final tabIndex = context.read<AppStateProvider>().tabIndex;
    if (tabIndex != 1) return false;
    // Don't intercept if a text field has focus
    final focus = FocusManager.instance.primaryFocus;
    if (focus?.context?.widget is EditableText) return false;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.space && event is KeyDownEvent) {
      _player.playOrPause();
      return true;
    }

    // Arrow keys only when nothing specific is focused (focusNode is the
    // trim screen's own node, or nothing at all)
    final nothingFocused = focus == null ||
        focus == _focusNode ||
        focus.context == null;
    if (!nothingFocused) return false;

    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight) {
      final shift = HardwareKeyboard.instance.isShiftPressed;
      final step = shift ? 15000 : 5000;
      final delta = key == LogicalKeyboardKey.arrowLeft ? -step : step;
      final fileInfo = context.read<AppStateProvider>().fileInfo;
      if (fileInfo == null) return false;
      final newMs = (_position.inMilliseconds + delta)
          .clamp(0, fileInfo.duration.inMilliseconds);
      _onSeek(Duration(milliseconds: newMs));
      return true;
    }

    return false;
  }

  Future<void> _loadVideo(String path) async {
    await _player.open(Media(Uri.file(path).toString()), play: false);
  }

  void _onSeek(Duration position) {
    setState(() => _position = position);
    _player.seek(position);
  }

  void _setStart() {
    final appState = context.read<AppStateProvider>();
    appState.setTrimStart(_position);
    if (appState.trimEnd <= _position) {
      final total = appState.fileInfo!.duration;
      final pushed = _position.inMilliseconds + 1000;
      appState.setTrimEnd(
        Duration(milliseconds: pushed.clamp(0, total.inMilliseconds)),
      );
    }
  }

  void _setEnd() {
    final appState = context.read<AppStateProvider>();
    if (_position <= appState.trimStart) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End must be after start'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    appState.setTrimEnd(_position);
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final fileInfo = appState.fileInfo;

    if (fileInfo == null) {
      return const Center(
        child: Text(
          'Load a video to use Trim',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
        ),
      );
    }

    final total = fileInfo.duration;

    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: Colors.black,
                child: Video(
                  controller: _controller,
                  fit: BoxFit.contain,
                  controls: NoVideoControls,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _fmt(_position),
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
              const Spacer(),
              Text(
                _fmt(total),
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TrimTimeline(
            total: total,
            start: appState.trimStart,
            end: appState.trimEnd,
            position: _position,
            onSeek: _onSeek,
          ),
          const SizedBox(height: 8),
          _buildControls(),
          const SizedBox(height: 4),
        ],
      ),
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildMarkerButton(
          label: 'Set Start',
          icon: Icons.skip_previous_rounded,
          onPressed: _setStart,
        ),
        const SizedBox(width: 16),
        _buildPlayPause(),
        const SizedBox(width: 16),
        _buildMarkerButton(
          label: 'Set End',
          icon: Icons.skip_next_rounded,
          onPressed: _setEnd,
        ),
      ],
    );
  }

  Widget _buildMarkerButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return _FocusableButton(
      onPressed: onPressed,
      builder: (focused) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: focused ? AppTheme.accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppTheme.accent, size: 22),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayPause() {
    return _FocusableButton(
      onPressed: () => _player.playOrPause(),
      builder: (focused) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.accent,
          shape: BoxShape.circle,
          border: Border.all(
            color: focused ? Colors.white : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Icon(
          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 22,
        ),
      ),
    );
  }
}

class _FocusableButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget Function(bool focused) builder;

  const _FocusableButton({
    required this.onPressed,
    required this.builder,
  });

  @override
  State<_FocusableButton> createState() => _FocusableButtonState();
}

class _FocusableButtonState extends State<_FocusableButton> {
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
        child: GestureDetector(
          onTap: widget.onPressed,
          child: widget.builder(_focused),
        ),
      ),
    );
  }
}
