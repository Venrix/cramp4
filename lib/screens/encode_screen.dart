import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state_provider.dart';
import '../providers/settings_provider.dart';
import '../services/ffmpeg_service.dart';
import '../theme/app_theme.dart';
import '../widgets/audio_settings_card.dart';
import '../widgets/filename_template_field.dart';
import '../widgets/process_queue_card.dart';
import '../widgets/video_settings_card.dart';

class EncodeScreen extends StatefulWidget {
  const EncodeScreen({super.key});

  @override
  State<EncodeScreen> createState() => _EncodeScreenState();
}

class _EncodeScreenState extends State<EncodeScreen> {
  // Settings shrink-wrap to content, capped here. Tall enough for the output
  // filename card (with its preview line) plus the video/audio cards below it.
  static const double _maxSettingsHeight = 560;
  // Queue floor; below this the page scrolls instead.
  static const double _minQueueHeight = 220;

  final GlobalKey _settingsKey = GlobalKey();
  double _settingsHeight = 0;

  // Measure settings so the queue gets an explicit height (its inner ListView
  // rules out Expanded and SliverFillRemaining).
  void _measureSettings() {
    final box = _settingsKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    if ((box.size.height - _settingsHeight).abs() > 0.5) {
      setState(() => _settingsHeight = box.size.height);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureSettings());

    return LayoutBuilder(
      builder: (context, constraints) {
        // Queue fills the leftover space, but never below its min.
        final queueHeight = (constraints.maxHeight - _settingsHeight)
            .clamp(_minQueueHeight, double.infinity)
            .toDouble();

        return SingleChildScrollView(
          child: Column(
            children: [
              _SettingsPanels(key: _settingsKey, maxHeight: _maxSettingsHeight),
              SizedBox(height: queueHeight, child: const _QueuePanel()),
            ],
          ),
        );
      },
    );
  }
}

class _SettingsPanels extends StatefulWidget {
  // Cap the shrink-wrapped settings; content taller than this scrolls inside.
  final double maxHeight;

  const _SettingsPanels({super.key, required this.maxHeight});

  @override
  State<_SettingsPanels> createState() => _SettingsPanelsState();
}

class _SettingsPanelsState extends State<_SettingsPanels> {
  late final TextEditingController _templateController;

  @override
  void initState() {
    super.initState();
    _templateController = TextEditingController(
        text: context.read<AppStateProvider>().filenameTemplateOverride);
  }

  @override
  void dispose() {
    _templateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppStateProvider>();
    final settings = context.watch<SettingsProvider>();
    final resolvedTemplate = const FfmpegService()
        .resolveTemplateDefault(_templateController.text, settings.filenameTemplate);
    final preview = previewOutputName(
      template: resolvedTemplate,
      fileInfo: appState.fileInfo,
      settings: appState.settings,
      trimStart: appState.trimStart,
      trimEnd: appState.trimEnd,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: widget.maxHeight),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.drive_file_rename_outline,
                            size: 22, color: AppTheme.accent),
                        SizedBox(width: 8),
                        Text(
                          'Output Filename',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    FilenameTemplateField(
                      controller: _templateController,
                      presets: kEncodeTemplatePresets,
                      onChanged: (v) {
                        context
                            .read<AppStateProvider>()
                            .setFilenameTemplateOverride(v);
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Output: $preview',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Both cards match the taller one's height.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: const [
                  Expanded(child: VideoSettingsCard()),
                  SizedBox(width: 12),
                  Expanded(child: AudioSettingsCard()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueuePanel extends StatelessWidget {
  const _QueuePanel();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: ProcessQueueCard(),
    );
  }
}
