import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/encode_settings.dart';
import '../models/file_info.dart';
import '../services/ffprobe_service.dart';

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

  int get tabIndex => _tabIndex;
  FileInfo? get fileInfo => _fileInfo;
  EncodeSettings get settings => _settings;
  bool get isLoadingFile => _isLoadingFile;
  String? get fileError => _fileError;
  Duration get trimStart => _trimStart;
  Duration get trimEnd => _trimEnd;

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

  Future<void> pickFile(String ffprobePath) async {
    final result = await FilePicker.pickFiles(
      type: FileType.video,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final path = result.files.first.path;
    if (path == null) return;
    await _probeFile(path, ffprobePath);
  }

  Future<void> loadFile(String path, String ffprobePath) =>
      _probeFile(path, ffprobePath);

  Future<void> _probeFile(String path, String ffprobePath) async {
    _isLoadingFile = true;
    _fileError = null;
    notifyListeners();

    try {
      final service = FfprobeService(ffprobePath: ffprobePath);
      _fileInfo = await service.probe(path);
      _fileError = null;
      _applyFileDefaults(_fileInfo!);
    } catch (e) {
      _fileError = e.toString();
      _fileInfo = null;
    } finally {
      _isLoadingFile = false;
      notifyListeners();
    }
  }

  void _applyFileDefaults(FileInfo info) {
    final codec = videoCodecFromFfprobe(info.videoCodec);
    if (codec != null) _settings.videoCodec = codec;

    _settings.audioFormat = AudioFormat.copy;

    final bitrate = nearestAudioBitrate(info.audioBitrate ~/ 1000);
    if (bitrate != null) _settings.audioBitrateKbps = bitrate;

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
