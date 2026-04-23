import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _keyFfmpegPath = 'ffmpeg_path';
  static const _keyOutputDir = 'output_dir';
  static const _keyOutputSuffix = 'output_suffix';

  String _ffmpegPath = '';
  String _outputDir = '';
  String _outputSuffix = '_cramp4';

  String get ffmpegPath => _ffmpegPath;
  String get outputDir => _outputDir;
  String get outputSuffix => _outputSuffix;

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
    _outputSuffix = prefs.getString(_keyOutputSuffix) ?? '_cramp4';
    notifyListeners();
  }

  Future<void> setFfmpegPath(String path) async {
    _ffmpegPath = path;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFfmpegPath, path);
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
