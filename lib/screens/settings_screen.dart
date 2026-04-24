import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/settings_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/hover_text_field.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ffmpegController;
  late TextEditingController _outputDirController;
  late TextEditingController _prefixController;
  late TextEditingController _suffixController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _ffmpegController = TextEditingController(text: settings.ffmpegPath);
    _outputDirController = TextEditingController(text: settings.outputDir);
    _prefixController = TextEditingController(text: settings.outputPrefix);
    _suffixController = TextEditingController(text: settings.outputSuffix);
  }

  @override
  void dispose() {
    _ffmpegController.dispose();
    _outputDirController.dispose();
    _prefixController.dispose();
    _suffixController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // FFmpeg card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(Icons.terminal_outlined, 'FFmpeg'),
                const SizedBox(height: 16),
                _fieldLabel('FFmpeg Binary Path'),
                const SizedBox(height: 6),
                IntrinsicHeight(
                  child: Row(
                  children: [
                    Expanded(
                      child: HoverTextField(
                        controller: _ffmpegController,
                        decoration: const InputDecoration(
                          hintText: 'Leave empty to use system PATH',
                        ),
                        onChanged: settings.setFfmpegPath,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _browseButton(() async {
                      final result = await FilePicker.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['exe', ''],
                      );
                      if (result != null && result.files.first.path != null) {
                        final path = result.files.first.path!;
                        _ffmpegController.text = path;
                        settings.setFfmpegPath(path);
                      }
                    }),
                  ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Output card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(Icons.folder_outlined, 'Output'),
                const SizedBox(height: 16),
                _fieldLabel('Output Folder'),
                const SizedBox(height: 6),
                IntrinsicHeight(
                  child: Row(
                  children: [
                    Expanded(
                      child: HoverTextField(
                        controller: _outputDirController,
                        decoration: const InputDecoration(
                          hintText: 'Leave empty to use same folder as input',
                        ),
                        onChanged: settings.setOutputDir,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _browseButton(() async {
                      final result = await FilePicker.getDirectoryPath();
                      if (result != null) {
                        _outputDirController.text = result;
                        settings.setOutputDir(result);
                      }
                    }),
                  ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Output Filename Prefix'),
                          const SizedBox(height: 6),
                          HoverTextField(
                            controller: _prefixController,
                            decoration: const InputDecoration(
                              hintText: 'None',
                            ),
                            onChanged: settings.setOutputPrefix,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _fieldLabel('Output Filename Suffix'),
                          const SizedBox(height: 6),
                          HoverTextField(
                            controller: _suffixController,
                            decoration: const InputDecoration(
                              hintText: '_cramp4',
                            ),
                            onChanged: settings.setOutputSuffix,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Shell Integration card
        Consumer<SettingsProvider>(
          builder: (context, settings, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cardHeader(Icons.mouse_outlined, 'Shell Integration'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '"Open in cramp4" context menu',
                              style: TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Adds right-click menu entry for video files.',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      OutlinedButton(
                        onPressed: () async {
                          if (settings.contextMenuRegistered) {
                            await settings.unregisterContextMenu();
                          } else {
                            await settings.registerContextMenu();
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: settings.contextMenuRegistered
                              ? AppTheme.textSecondary
                              : AppTheme.accent,
                          side: BorderSide(
                            color: settings.contextMenuRegistered
                                ? AppTheme.textSecondary
                                : AppTheme.accent,
                          ),
                        ),
                        child: Text(
                          settings.contextMenuRegistered ? 'Remove' : 'Add',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cardHeader(IconData icon, String text) => Row(
        children: [
          Icon(icon, size: 26, color: AppTheme.accent),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );

  Widget _fieldLabel(String text) => Text(
        text,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 11,
          letterSpacing: 0.8,
        ),
      );

  Widget _browseButton(VoidCallback onPressed) => SizedBox(
        height: double.infinity,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          child: const Text('Browse'),
        ),
      );
}
