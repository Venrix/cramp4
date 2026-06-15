import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/encode_settings.dart';
import '../models/file_info.dart';
import '../providers/settings_provider.dart';
import '../services/ffprobe_service.dart';

const _videoExtensions = {'.mp4', '.mkv', '.mov', '.avi', '.wmv', '.webm', '.m4v'};

DateTime _fileSortDate(String path, FolderSortField field) {
  final f = File(path);
  if (field == FolderSortField.dateModified) return f.lastModifiedSync();
  // dateCreated: FileStat.changed maps to creation time on Windows
  return f.statSync().changed;
}

class AppStateProvider extends ChangeNotifier {
  static const _keyVideoEnabled = 'enc_video_enabled';
  static const _keyVideoCodec = 'enc_video_codec';
  static const _keyResolutionScale = 'enc_resolution_scale';
  static const _keyTargetSizeMB = 'enc_target_size_mb';
  static const _keyAudioEnabled = 'enc_audio_enabled';
  static const _keyAudioFormat = 'enc_audio_format';
  static const _keyAudioBitrate = 'enc_audio_bitrate';

  int _tabIndex = 0;
  FileInfo? _fileInfo;
  final EncodeSettings _settings = EncodeSettings();
  bool _isLoadingFile = false;
  String? _fileError;
  Duration _trimStart = Duration.zero;
  Duration _trimEnd = Duration.zero;
  // Per-session override of the filename template. {templatedefault} inherits
  // the Settings template. Not persisted; survives file switches in a session.
  String _filenameTemplateOverride = '{templatedefault}';
  List<String> _folderFiles = [];
  int _folderIndex = -1;
  String? _folderPath;

  int get tabIndex => _tabIndex;
  FileInfo? get fileInfo => _fileInfo;
  EncodeSettings get settings => _settings;
  bool get isLoadingFile => _isLoadingFile;
  String? get fileError => _fileError;
  Duration get trimStart => _trimStart;
  Duration get trimEnd => _trimEnd;
  String get filenameTemplateOverride => _filenameTemplateOverride;
  bool get hasFolderLoaded => _folderFiles.isNotEmpty;
  int get folderIndex => _folderIndex;
  int get folderTotal => _folderFiles.length;
  String? get folderPath => _folderPath;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _settings.videoEnabled = prefs.getBool(_keyVideoEnabled) ?? true;
    _settings.videoCodec = VideoCodec.values.byName(
        prefs.getString(_keyVideoCodec) ?? VideoCodec.copy.name);
    _settings.resolutionScale = ResolutionScale.values.byName(
        prefs.getString(_keyResolutionScale) ?? ResolutionScale.original.name);
    final targetSize = prefs.getDouble(_keyTargetSizeMB);
    _settings.targetSizeMB = targetSize;
    _settings.audioEnabled = prefs.getBool(_keyAudioEnabled) ?? true;
    _settings.audioFormat = AudioFormat.values.byName(
        prefs.getString(_keyAudioFormat) ?? AudioFormat.copy.name);
    _settings.audioBitrateKbps = prefs.getInt(_keyAudioBitrate) ?? 128;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyVideoEnabled, _settings.videoEnabled);
    await prefs.setString(_keyVideoCodec, _settings.videoCodec.name);
    await prefs.setString(_keyResolutionScale, _settings.resolutionScale.name);
    if (_settings.targetSizeMB != null) {
      await prefs.setDouble(_keyTargetSizeMB, _settings.targetSizeMB!);
    } else {
      await prefs.remove(_keyTargetSizeMB);
    }
    await prefs.setBool(_keyAudioEnabled, _settings.audioEnabled);
    await prefs.setString(_keyAudioFormat, _settings.audioFormat.name);
    await prefs.setInt(_keyAudioBitrate, _settings.audioBitrateKbps);
  }

  void setTab(int index) {
    _tabIndex = index;
    notifyListeners();
  }

  void _clearFolderState() {
    _folderFiles = [];
    _folderIndex = -1;
    _folderPath = null;
  }

  void clearFile() {
    _fileInfo = null;
    _fileError = null;
    _trimStart = Duration.zero;
    _trimEnd = Duration.zero;
    _clearFolderState();
    notifyListeners();
  }

  Future<void> pickFile(String ffprobePath, SettingsProvider settingsProvider) async {
    _clearFolderState();
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    await _probeFile(path, ffprobePath, settingsProvider);
  }

  Future<void> loadFile(String path, String ffprobePath, SettingsProvider settingsProvider) {
    _clearFolderState();
    return _probeFile(path, ffprobePath, settingsProvider);
  }

  Future<void> pickFolder(
    String ffprobePath,
    SettingsProvider settingsProvider, {
    required FolderSortField sortField,
    required FolderSortDirection sortDirection,
    required String blacklistPattern,
  }) async {
    final dir = await FilePicker.getDirectoryPath();
    if (dir == null) return;
    await _loadFolder(dir, ffprobePath, settingsProvider,
        sortField: sortField,
        sortDirection: sortDirection,
        blacklistPattern: blacklistPattern);
  }

  Future<void> _loadFolder(
    String dirPath,
    String ffprobePath,
    SettingsProvider settingsProvider, {
    required FolderSortField sortField,
    required FolderSortDirection sortDirection,
    required String blacklistPattern,
  }) async {
    _isLoadingFile = true;
    _fileError = null;
    notifyListeners();

    try {
      final allEntries = await Directory(dirPath).list(recursive: false).toList();

      final videoFiles = allEntries
          .whereType<File>()
          .where((f) {
            final ext = f.path.contains('.')
                ? '.${f.path.split('.').last.toLowerCase()}'
                : '';
            return _videoExtensions.contains(ext);
          })
          .map((f) => f.path)
          .toList();

      List<String> filtered = videoFiles;
      if (blacklistPattern.isNotEmpty) {
        try {
          final regex = RegExp(blacklistPattern);
          filtered = videoFiles.where((p) {
            final filename = p.replaceAll('\\', '/').split('/').last;
            return !regex.hasMatch(filename);
          }).toList();
        } catch (_) {
          // Invalid regex — skip filtering
        }
      }

      if (filtered.isEmpty) {
        _folderFiles = [];
        _folderIndex = -1;
        _folderPath = dirPath;
        _fileError = 'No video files found in folder';
        _isLoadingFile = false;
        notifyListeners();
        return;
      }

      if (sortField == FolderSortField.title) {
        filtered.sort((a, b) {
          final nameA = a.replaceAll('\\', '/').split('/').last.toLowerCase();
          final nameB = b.replaceAll('\\', '/').split('/').last.toLowerCase();
          return sortDirection == FolderSortDirection.ascending
              ? nameA.compareTo(nameB)
              : nameB.compareTo(nameA);
        });
      } else {
        filtered.sort((a, b) {
          final dateA = _fileSortDate(a, sortField);
          final dateB = _fileSortDate(b, sortField);
          return sortDirection == FolderSortDirection.ascending
              ? dateA.compareTo(dateB)
              : dateB.compareTo(dateA);
        });
      }

      _folderFiles = filtered;
      _folderPath = dirPath;
      _folderIndex = 0;
    } catch (e) {
      _fileError = e.toString();
      _folderFiles = [];
      _folderIndex = -1;
      _isLoadingFile = false;
      notifyListeners();
      return;
    }

    await _probeFile(_folderFiles[0], ffprobePath, settingsProvider);
    // _isLoadingFile reset by _probeFile's finally block
  }

  Future<void> navigateFolderPrev(String ffprobePath, SettingsProvider settingsProvider) async {
    if (_isLoadingFile || _folderIndex <= 0) return;
    _folderIndex--;
    await _probeFile(_folderFiles[_folderIndex], ffprobePath, settingsProvider);
  }

  Future<void> navigateFolderNext(String ffprobePath, SettingsProvider settingsProvider) async {
    if (_isLoadingFile || _folderIndex >= _folderFiles.length - 1) return;
    _folderIndex++;
    await _probeFile(_folderFiles[_folderIndex], ffprobePath, settingsProvider);
  }

  Future<void> _probeFile(String path, String ffprobePath, SettingsProvider settingsProvider) async {
    _isLoadingFile = true;
    _fileError = null;
    notifyListeners();

    try {
      final service = FfprobeService(ffprobePath: ffprobePath);
      _fileInfo = await service.probe(path);
      _fileError = null;
      _applyFileDefaults(_fileInfo!, settingsProvider);
    } catch (e) {
      _fileError = e.toString();
      _fileInfo = null;
    } finally {
      _isLoadingFile = false;
      notifyListeners();
    }
  }

  void _applyFileDefaults(FileInfo info, SettingsProvider settingsProvider) {
    _settings.videoCodec = settingsProvider.defaultVideoCodec;
    _settings.resolutionScale = settingsProvider.defaultResolution;
    _settings.targetSizeMB = null;
    _settings.audioFormat = settingsProvider.defaultAudioFormat;
    _settings.audioBitrateKbps = settingsProvider.defaultAudioBitrate;

    _trimStart = Duration.zero;
    _trimEnd = info.duration;
  }

  void setTrimStart(Duration d) {
    _trimStart = d;
    notifyListeners();
  }

  void setTrimEnd(Duration d) {
    _trimEnd = d;
    notifyListeners();
  }

  // No notify: nothing visual depends on it; read fresh when encoding starts.
  void setFilenameTemplateOverride(String template) {
    _filenameTemplateOverride = template;
  }

  void setVideoEnabled(bool v) {
    _settings.videoEnabled = v;
    notifyListeners();
    _save();
  }

  void setTargetSizeMB(double? v) {
    _settings.targetSizeMB = v;
    notifyListeners();
    _save();
  }

  void setVideoCodec(VideoCodec v) {
    _settings.videoCodec = v;
    if (!v.supportsTwoPass) {
      _settings.targetSizeMB = null;
    }
    notifyListeners();
    _save();
  }

  void setResolutionScale(ResolutionScale v) {
    _settings.resolutionScale = v;
    notifyListeners();
    _save();
  }

  void setAudioEnabled(bool v) {
    _settings.audioEnabled = v;
    notifyListeners();
    _save();
  }

  void setAudioBitrateKbps(int v) {
    _settings.audioBitrateKbps = v;
    notifyListeners();
    _save();
  }

  void setAudioFormat(AudioFormat v) {
    _settings.audioFormat = v;
    notifyListeners();
    _save();
  }
}
