import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/encode_settings.dart';
import '../providers/app_state_provider.dart';
import '../theme/app_theme.dart';
import 'full_width_dropdown.dart';
import 'hover_text_field.dart';

class VideoSettingsCard extends StatelessWidget {
  const VideoSettingsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final settings = appState.settings;
    final videoOn = settings.videoEnabled;

    final originalCodec = videoCodecFromFfprobe(appState.fileInfo?.videoCodec);

    // Parse source height from "WxH" string
    final resolution = appState.fileInfo?.resolution;
    final sourceHeight = resolution != null && resolution.contains('x')
        ? int.tryParse(resolution.split('x').last)
        : null;

    final availableScales = ResolutionScale.values.where((s) {
      if (s == ResolutionScale.original) return true;
      final h = s.maxHeight;
      if (h == null || sourceHeight == null) return true;
      return h < sourceHeight;
    }).toList();

    return Card(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.videocam_outlined, size: 26, color: AppTheme.accent),
                const SizedBox(width: 8),
                const Text(
                  'Video Settings',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Text(
                  'VIDEO',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, letterSpacing: 0.8),
                ),
                const SizedBox(width: 8),
                Transform.scale(
                  scale: 0.75,
                  child: Switch(
                    value: videoOn,
                    onChanged: appState.setVideoEnabled,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            IgnorePointer(
              ignoring: !videoOn,
              child: AnimatedOpacity(
                opacity: videoOn ? 1.0 : 0.4,
                duration: const Duration(milliseconds: 150),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('TARGET FILE SIZE'),
                    const SizedBox(height: 6),
                    _TargetSizeField(settings: settings, appState: appState),
                    const SizedBox(height: 14),
                    _fieldLabel('CODEC'),
                    const SizedBox(height: 6),
                    FullWidthDropdown<VideoCodec>(
                      value: settings.videoCodec,
                      items: VideoCodec.values,
                      labelOf: (v) => v.displayName,
                      onChanged: (v) => appState.setVideoCodec(v!),
                      originalValue: originalCodec,
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel('DOWNSCALING'),
                    const SizedBox(height: 6),
                    FullWidthDropdown<ResolutionScale>(
                      value: availableScales.contains(settings.resolutionScale)
                          ? settings.resolutionScale
                          : ResolutionScale.original,
                      items: availableScales,
                      labelOf: (v) => v.displayName,
                      onChanged: (v) => appState.setResolutionScale(v!),
                    ),
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

class _TargetSizeField extends StatefulWidget {
  final EncodeSettings settings;
  final AppStateProvider appState;

  const _TargetSizeField({required this.settings, required this.appState});

  @override
  State<_TargetSizeField> createState() => _TargetSizeFieldState();
}

class _TargetSizeFieldState extends State<_TargetSizeField> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.settings.targetSizeMB?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HoverTextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      decoration: const InputDecoration(
        suffixText: 'MB',
        hintText: 'e.g. 20',
      ),
      onChanged: (v) {
        final parsed = double.tryParse(v);
        widget.appState.setTargetSizeMB(parsed);
      },
    );
  }
}

