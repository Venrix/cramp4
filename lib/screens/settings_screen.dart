import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/encode_settings.dart';
import '../providers/app_state_provider.dart';
import '../providers/settings_provider.dart';
import '../services/update_service.dart';
import '../theme/app_theme.dart';
import '../widgets/filename_template_field.dart';
import '../widgets/full_width_dropdown.dart';
import '../widgets/hover_text_field.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late TextEditingController _ffmpegController;
  late TextEditingController _outputDirController;
  late TextEditingController _templateController;
  late TextEditingController _blacklistController;

  UpdateInfo? _updateInfo;
  bool _checkingUpdate = false;
  bool _downloading = false;
  double _downloadProgress = 0;
  String? _updateError;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _ffmpegController = TextEditingController(text: settings.ffmpegPath);
    _outputDirController = TextEditingController(text: settings.outputDir);
    _templateController = TextEditingController(text: settings.filenameTemplate);
    _blacklistController = TextEditingController(text: settings.blacklistPattern);
  }

  @override
  void dispose() {
    _ffmpegController.dispose();
    _outputDirController.dispose();
    _templateController.dispose();
    _blacklistController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final appState = context.watch<AppStateProvider>();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // FFmpeg card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(Icons.terminal_outlined, 'FFmpeg', onReset: () {
                  settings.setFfmpegPath('');
                  _ffmpegController.clear();
                }),
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
                _cardHeader(Icons.folder_outlined, 'Output', onReset: () {
                  settings.resetOutput();
                  _outputDirController.clear();
                  _templateController.text =
                      SettingsProvider.defaultFilenameTemplate;
                  setState(() {});
                }),
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
                _fieldLabel('Filename Template'),
                const SizedBox(height: 6),
                FilenameTemplateField(
                  controller: _templateController,
                  onChanged: (v) {
                    settings.setFilenameTemplate(v);
                    setState(() {});
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Example: ${_templateExample(appState)}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Encoding Defaults card
        Consumer<SettingsProvider>(
          builder: (context, settings, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cardHeader(Icons.tune_outlined, 'Encoding Defaults',
                      onReset: settings.resetEncodingDefaults),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Video Codec'),
                            const SizedBox(height: 6),
                            FullWidthDropdown<VideoCodec>(
                              value: settings.defaultVideoCodec,
                              items: VideoCodec.values,
                              labelOf: (v) => v.displayName,
                              onChanged: (v) {
                                if (v != null) settings.setDefaultVideoCodec(v);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Resolution'),
                            const SizedBox(height: 6),
                            FullWidthDropdown<ResolutionScale>(
                              value: settings.defaultResolution,
                              items: ResolutionScale.values,
                              labelOf: (v) => v.displayName,
                              onChanged: (v) {
                                if (v != null) settings.setDefaultResolution(v);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Audio Format'),
                            const SizedBox(height: 6),
                            FullWidthDropdown<AudioFormat>(
                              value: settings.defaultAudioFormat,
                              items: AudioFormat.values,
                              labelOf: (v) => v.displayName,
                              onChanged: (v) {
                                if (v != null) settings.setDefaultAudioFormat(v);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Audio Bitrate'),
                            const SizedBox(height: 6),
                            FullWidthDropdown<int>(
                              value: settings.defaultAudioBitrate,
                              items: const [320, 256, 192, 128, 96, 64, 32],
                              labelOf: (v) => '${v}k',
                              onChanged: (v) {
                                if (v != null) settings.setDefaultAudioBitrate(v);
                              },
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
        ),
        if (Platform.isWindows) ...[
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
                        ).copyWith(
                          side: WidgetStateProperty.resolveWith((states) {
                            if (states.contains(WidgetState.focused)) {
                              return const BorderSide(color: AppTheme.accent, width: 1.5);
                            }
                            return BorderSide(
                              color: settings.contextMenuRegistered
                                  ? AppTheme.textSecondary
                                  : AppTheme.accent,
                            );
                          }),
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
        if (!UpdateService.isPortable) ...[
        const SizedBox(height: 16),
        // Updates card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _cardHeader(Icons.system_update_outlined, 'Updates'),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _updateInfo != null
                                ? 'Update available: v${_updateInfo!.version}'
                                : _updateError != null
                                    ? _updateError!
                                    : _checkingUpdate
                                        ? 'Checking for updates...'
                                        : 'Check for new releases on GitHub.',
                            style: TextStyle(
                              color: _updateInfo != null
                                  ? AppTheme.accent
                                  : _updateError != null
                                      ? Colors.red[300]
                                      : AppTheme.textPrimary,
                              fontSize: 13,
                            ),
                          ),
                          if (_downloading) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: _downloadProgress > 0
                                    ? _downloadProgress
                                    : null,
                                backgroundColor: AppTheme.surface,
                                color: AppTheme.accent,
                                minHeight: 4,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton(
                      onPressed: _checkingUpdate || _downloading
                          ? null
                          : _updateInfo != null
                              ? _installUpdate
                              : _checkForUpdate,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        disabledForegroundColor: AppTheme.textSecondary,
                        disabledMouseCursor: SystemMouseCursors.basic,
                      ).copyWith(
                        side: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.disabled)) {
                            return BorderSide.none;
                          }
                          if (states.contains(WidgetState.focused)) {
                            return const BorderSide(color: AppTheme.accent, width: 1.5);
                          }
                          return const BorderSide(color: AppTheme.accent);
                        }),
                      ),
                      child: Text(
                        _downloading
                            ? 'Installing...'
                            : _checkingUpdate
                                ? 'Checking...'
                                : _updateInfo != null
                                    ? 'Install'
                                    : 'Check for Updates',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ], // !isPortable
        ], // Platform.isWindows
        const SizedBox(height: 16),
        // Folder Navigation card
        Consumer<SettingsProvider>(
          builder: (context, settings, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _cardHeader(Icons.video_library_outlined, 'Folder Navigation',
                      onReset: () {
                    settings.resetFolderNavigation();
                    _blacklistController.text = r'_cramp4';
                  }),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Sort By'),
                            const SizedBox(height: 6),
                            FullWidthDropdown<FolderSortField>(
                              value: settings.folderSortField,
                              items: FolderSortField.values,
                              labelOf: (v) => switch (v) {
                                FolderSortField.dateCreated => 'Date Created',
                                FolderSortField.dateModified => 'Date Modified',
                                FolderSortField.title => 'Title',
                              },
                              onChanged: (v) {
                                if (v != null) settings.setFolderSortField(v);
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _fieldLabel('Sort Direction'),
                            const SizedBox(height: 6),
                            FullWidthDropdown<FolderSortDirection>(
                              value: settings.folderSortDirection,
                              items: FolderSortDirection.values,
                              labelOf: (v) => switch (v) {
                                FolderSortDirection.ascending => 'Ascending',
                                FolderSortDirection.descending => 'Descending',
                              },
                              onChanged: (v) {
                                if (v != null) settings.setFolderSortDirection(v);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _fieldLabel('Blacklist Pattern'),
                  const SizedBox(height: 6),
                  HoverTextField(
                    controller: _blacklistController,
                    decoration: const InputDecoration(hintText: r'_cramp4'),
                    onChanged: settings.setBlacklistPattern,
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Filenames matching this regex are excluded when loading a folder.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _checkForUpdate() async {
    setState(() {
      _checkingUpdate = true;
      _updateError = null;
      _updateInfo = null;
    });
    try {
      final info = await UpdateService.checkForUpdate();
      if (!mounted) return;
      setState(() {
        _checkingUpdate = false;
        _updateInfo = info;
        if (info == null) _updateError = 'Already on the latest version.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _checkingUpdate = false;
        _updateError = 'Failed to check for updates.';
      });
    }
  }

  Future<void> _installUpdate() async {
    if (_updateInfo == null) return;
    setState(() {
      _downloading = true;
      _downloadProgress = 0;
    });
    try {
      await UpdateService.downloadAndInstall(
        _updateInfo!,
        (progress) {
          if (mounted) setState(() => _downloadProgress = progress);
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _downloading = false;
        _updateError = 'Update failed. Try downloading manually.';
        _updateInfo = null;
      });
    }
  }

  Widget _cardHeader(IconData icon, String text, {VoidCallback? onReset}) => Row(
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
          if (onReset != null) ...[
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.restart_alt, size: 18),
              color: AppTheme.textSecondary,
              tooltip: 'Reset to defaults',
              onPressed: onReset,
              mouseCursor: SystemMouseCursors.click,
              style: IconButton.styleFrom(
                padding: const EdgeInsets.all(4),
                minimumSize: const Size(28, 28),
              ),
            ),
          ],
        ],
      );

  // Live preview of the current template — real file/trim when one is loaded,
  // otherwise sample values.
  String _templateExample(AppStateProvider appState) => previewOutputName(
        template: _templateController.text,
        fileInfo: appState.fileInfo,
        settings: appState.settings,
        trimStart: appState.trimStart,
        trimEnd: appState.trimEnd,
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
          style: const ButtonStyle(
            padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
          ),
          child: const Text('Browse'),
        ),
      );
}
