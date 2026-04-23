import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../models/encode_settings.dart';
import '../models/file_info.dart';
import '../services/ffprobe_service.dart';

class AppStateProvider extends ChangeNotifier {
  int _tabIndex = 0;
  FileInfo? _fileInfo;
  final EncodeSettings _settings = EncodeSettings();
  bool _isLoadingFile = false;
  String? _fileError;

  int get tabIndex => _tabIndex;
  FileInfo? get fileInfo => _fileInfo;
  EncodeSettings get settings => _settings;
  bool get isLoadingFile => _isLoadingFile;
  String? get fileError => _fileError;

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
  }

  void setVideoEnabled(bool v) {
    _settings.videoEnabled = v;
    notifyListeners();
  }

  void setTargetSizeMB(double? v) {
    _settings.targetSizeMB = v;
    notifyListeners();
  }

  void setVideoCodec(VideoCodec v) {
    _settings.videoCodec = v;
    notifyListeners();
  }

  void setResolutionScale(ResolutionScale v) {
    _settings.resolutionScale = v;
    notifyListeners();
  }

  void setAudioEnabled(bool v) {
    _settings.audioEnabled = v;
    notifyListeners();
  }

  void setAudioBitrateKbps(int v) {
    _settings.audioBitrateKbps = v;
    notifyListeners();
  }

  void setAudioFormat(AudioFormat v) {
    _settings.audioFormat = v;
    notifyListeners();
  }
}
