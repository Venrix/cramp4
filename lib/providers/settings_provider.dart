import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyFfmpegPath = 'ffmpeg_path';
  static const _keyOutputDir = 'output_dir';
  static const _keyOutputPrefix = 'output_prefix';
  static const _keyOutputSuffix = 'output_suffix';
  static const _videoExtensions = [
    'mp4', 'mkv', 'avi', 'mov', 'wmv', 'webm', 'm4v', 'flv',
    'ts', 'm2ts', 'mpg', 'mpeg', '3gp', 'ogv', 'vob',
  ];
  static String _extKey(String ext) =>
      'HKCU\\Software\\Classes\\.$ext\\shell\\OpenInCramp4';

  String _ffmpegPath = '';
  String _outputDir = '';
  String _outputPrefix = '';
  String _outputSuffix = '_cramp4';
  bool _contextMenuRegistered = false;

  String get ffmpegPath => _ffmpegPath;
  String get outputDir => _outputDir;
  String get outputPrefix => _outputPrefix;
  String get outputSuffix => _outputSuffix;
  bool get contextMenuRegistered => _contextMenuRegistered;

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
    await _checkContextMenuStatus();
    notifyListeners();
  }

  Future<void> _checkContextMenuStatus() async {
    // Check the first extension as a proxy for all
    final result = await Process.run('reg', ['query', _extKey('mp4')]);
    _contextMenuRegistered = result.exitCode == 0;
  }

  Future<bool> registerContextMenu() async {
    final exe = Platform.resolvedExecutable;
    bool ok = true;
    for (final ext in _videoExtensions) {
      final key = _extKey(ext);
      final r1 = await Process.run('reg', [
        'add', key, '/ve', '/d', 'Open in cramp4', '/f',
      ]);
      await Process.run('reg', [
        'add', key, '/v', 'Icon', '/d', '"$exe",0', '/f',
      ]);
      final r2 = await Process.run('reg', [
        'add', '$key\\command', '/ve', '/d', '"$exe" "%1"', '/f',
      ]);
      if (r1.exitCode != 0 || r2.exitCode != 0) ok = false;
    }
    await _notifyShell();
    _contextMenuRegistered = ok;
    notifyListeners();
    return ok;
  }

  Future<bool> unregisterContextMenu() async {
    bool ok = true;
    for (final ext in _videoExtensions) {
      final result = await Process.run('reg', ['delete', _extKey(ext), '/f']);
      if (result.exitCode != 0) ok = false;
    }
    await _notifyShell();
    if (ok) _contextMenuRegistered = false;
    notifyListeners();
    return ok;
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
}
