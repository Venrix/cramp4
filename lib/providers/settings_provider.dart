import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/encode_settings.dart';

enum FolderSortField { dateCreated, dateModified, title }
enum FolderSortDirection { ascending, descending }

class SettingsProvider extends ChangeNotifier {
  static const _keyFfmpegPath = 'ffmpeg_path';
  static const _keyOutputDir = 'output_dir';
  static const _keyOutputPrefix = 'output_prefix';
  static const _keyOutputSuffix = 'output_suffix';
  static const _keyFolderSortField = 'folder_sort_field';
  static const _keyFolderSortDirection = 'folder_sort_direction';
  static const _keyBlacklistPattern = 'folder_blacklist_pattern';
  static const _keyDefaultVideoCodec = 'default_video_codec';
  static const _keyDefaultResolution = 'default_resolution';
  static const _keyDefaultAudioFormat = 'default_audio_format';
  static const _keyDefaultAudioBitrate = 'default_audio_bitrate';
  static const _shellKey =
      r'HKCU\Software\Classes\*\shell\OpenInCramp4';

  String _ffmpegPath = '';
  String _outputDir = '';
  String _outputPrefix = '';
  String _outputSuffix = '_cramp4';
  bool _contextMenuRegistered = false;
  FolderSortField _folderSortField = FolderSortField.dateCreated;
  FolderSortDirection _folderSortDirection = FolderSortDirection.ascending;
  String _blacklistPattern = r'_cramp4';
  VideoCodec _defaultVideoCodec = VideoCodec.copy;
  ResolutionScale _defaultResolution = ResolutionScale.original;
  AudioFormat _defaultAudioFormat = AudioFormat.copy;
  int _defaultAudioBitrate = 128;

  String get ffmpegPath => _ffmpegPath;
  String get outputDir => _outputDir;
  String get outputPrefix => _outputPrefix;
  String get outputSuffix => _outputSuffix;
  bool get contextMenuRegistered => _contextMenuRegistered;
  FolderSortField get folderSortField => _folderSortField;
  FolderSortDirection get folderSortDirection => _folderSortDirection;
  String get blacklistPattern => _blacklistPattern;
  VideoCodec get defaultVideoCodec => _defaultVideoCodec;
  ResolutionScale get defaultResolution => _defaultResolution;
  AudioFormat get defaultAudioFormat => _defaultAudioFormat;
  int get defaultAudioBitrate => _defaultAudioBitrate;

  bool get contextMenuSupported => Platform.isWindows;
  String get effectiveFfmpegPath => _ffmpegPath.isEmpty ? 'ffmpeg' : _ffmpegPath;
  String get effectiveFfprobePath {
    if (_ffmpegPath.isEmpty) return 'ffprobe';
    // If user set a custom ffmpeg path, derive ffprobe from same dir
    final normalized = _ffmpegPath.replaceAll('\\', '/');
    final dir = normalized.contains('/')
        ? normalized.substring(0, normalized.lastIndexOf('/') + 1)
        : '';
    return '${dir}ffprobe';
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _ffmpegPath = prefs.getString(_keyFfmpegPath) ?? '';
    _outputDir = prefs.getString(_keyOutputDir) ?? '';
    _outputPrefix = prefs.getString(_keyOutputPrefix) ?? '';
    _outputSuffix = prefs.getString(_keyOutputSuffix) ?? '_cramp4';
    _folderSortField = FolderSortField.values.byName(
        prefs.getString(_keyFolderSortField) ?? FolderSortField.dateCreated.name);
    _folderSortDirection = FolderSortDirection.values.byName(
        prefs.getString(_keyFolderSortDirection) ?? FolderSortDirection.ascending.name);
    _blacklistPattern = prefs.getString(_keyBlacklistPattern) ?? r'_cramp4';
    _defaultVideoCodec = VideoCodec.values.byName(
        prefs.getString(_keyDefaultVideoCodec) ?? VideoCodec.copy.name);
    _defaultResolution = ResolutionScale.values.byName(
        prefs.getString(_keyDefaultResolution) ?? ResolutionScale.original.name);
    _defaultAudioFormat = AudioFormat.values.byName(
        prefs.getString(_keyDefaultAudioFormat) ?? AudioFormat.copy.name);
    _defaultAudioBitrate = prefs.getInt(_keyDefaultAudioBitrate) ?? 128;
    if (Platform.isWindows) await _checkContextMenuStatus();
    notifyListeners();
  }

  Future<void> _checkContextMenuStatus() async {
    final result = await Process.run('reg', ['query', _shellKey]);
    _contextMenuRegistered = result.exitCode == 0;
  }

  Future<bool> registerContextMenu() async {
    if (!Platform.isWindows) return false;
    final exe = Platform.resolvedExecutable;
    final r1 = await Process.run('reg', [
      'add', _shellKey, '/ve', '/d', 'Open in cramp4', '/f',
    ]);
    await Process.run('reg', [
      'add', _shellKey, '/v', 'Icon', '/d', '"$exe",0', '/f',
    ]);
    // AppliesTo limits the entry to video files only
    await Process.run('reg', [
      'add', _shellKey, '/v', 'AppliesTo', '/d', 'System.Kind:=video', '/f',
    ]);
    final r2 = await Process.run('reg', [
      'add', '$_shellKey\\command', '/ve', '/d', '"$exe" "%1"', '/f',
    ]);
    await _notifyShell();
    _contextMenuRegistered = r1.exitCode == 0 && r2.exitCode == 0;
    notifyListeners();
    return _contextMenuRegistered;
  }

  Future<bool> unregisterContextMenu() async {
    if (!Platform.isWindows) return false;
    final result = await Process.run('reg', ['delete', _shellKey, '/f']);
    await _notifyShell();
    if (result.exitCode == 0) _contextMenuRegistered = false;
    notifyListeners();
    return result.exitCode == 0;
  }

  Future<void> _notifyShell() async {
    // SHChangeNotify(SHCNE_ASSOCCHANGED, SHCNF_IDLIST, 0, 0)
    // Tells the shell to refresh file association cache — no Explorer restart needed.
    await Process.run('powershell', [
      '-NoProfile', '-NonInteractive', '-Command',
      r"Add-Type -MemberDefinition '[DllImport(""shell32.dll"")] public static extern void SHChangeNotify(uint e, uint f, IntPtr a, IntPtr b);' -Name S -Namespace W; [W.S]::SHChangeNotify(0x08000000, 0x0000, [IntPtr]::Zero, [IntPtr]::Zero)",
    ]);
  }

  Future<void> setFfmpegPath(String path) async {
    _ffmpegPath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFfmpegPath, path);
  }

  Future<void> setOutputPrefix(String prefix) async {
    _outputPrefix = prefix;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOutputPrefix, prefix);
  }

  Future<void> setOutputDir(String dir) async {
    _outputDir = dir;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOutputDir, dir);
  }

  Future<void> setOutputSuffix(String suffix) async {
    _outputSuffix = suffix;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOutputSuffix, suffix);
  }

  Future<void> setFolderSortField(FolderSortField v) async {
    _folderSortField = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFolderSortField, v.name);
  }

  Future<void> setFolderSortDirection(FolderSortDirection v) async {
    _folderSortDirection = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFolderSortDirection, v.name);
  }

  Future<void> setBlacklistPattern(String pattern) async {
    _blacklistPattern = pattern;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyBlacklistPattern, pattern);
  }

  Future<void> resetOutput() async {
    _outputDir = '';
    _outputPrefix = '';
    _outputSuffix = '_cramp4';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyOutputDir);
    await prefs.remove(_keyOutputPrefix);
    await prefs.setString(_keyOutputSuffix, '_cramp4');
  }

  Future<void> resetEncodingDefaults() async {
    _defaultVideoCodec = VideoCodec.copy;
    _defaultResolution = ResolutionScale.original;
    _defaultAudioFormat = AudioFormat.copy;
    _defaultAudioBitrate = 128;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyDefaultVideoCodec);
    await prefs.remove(_keyDefaultResolution);
    await prefs.remove(_keyDefaultAudioFormat);
    await prefs.remove(_keyDefaultAudioBitrate);
  }

  Future<void> resetFolderNavigation() async {
    _folderSortField = FolderSortField.dateCreated;
    _folderSortDirection = FolderSortDirection.ascending;
    _blacklistPattern = r'_cramp4';
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyFolderSortField);
    await prefs.remove(_keyFolderSortDirection);
    await prefs.setString(_keyBlacklistPattern, r'_cramp4');
  }

  Future<void> setDefaultVideoCodec(VideoCodec v) async {
    _defaultVideoCodec = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultVideoCodec, v.name);
  }

  Future<void> setDefaultResolution(ResolutionScale v) async {
    _defaultResolution = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultResolution, v.name);
  }

  Future<void> setDefaultAudioFormat(AudioFormat v) async {
    _defaultAudioFormat = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyDefaultAudioFormat, v.name);
  }

  Future<void> setDefaultAudioBitrate(int v) async {
    _defaultAudioBitrate = v;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyDefaultAudioBitrate, v);
  }
}
