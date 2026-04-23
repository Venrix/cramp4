import 'dart:io';

import '../models/encode_settings.dart';
import '../models/file_info.dart';

class FfmpegService {
  final String ffmpegPath;

  const FfmpegService({this.ffmpegPath = 'ffmpeg'});

  int calculateVideoBitrateKbps({
    required double targetSizeMB,
    required double durationSeconds,
    required int audioBitrateKbps,
  }) {
    if (durationSeconds <= 0) return 1000;
    final totalKilobits = targetSizeMB * 8 * 1024;
    final videoBitrateKbps = (totalKilobits / durationSeconds) - audioBitrateKbps;
    return videoBitrateKbps.clamp(50, 100000).toInt();
  }

  List<String> buildPass1Args({
    required String inputPath,
    required EncodeSettings settings,
    required int videoBitrateKbps,
    required String passlogFile,
  }) {
    return [
      '-y',
      '-i', inputPath,
      ..._videoFilterArgs(settings),
      '-c:v', settings.videoCodec.ffmpegCodec,
      '-b:v', '${videoBitrateKbps}k',
      '-pass', '1',
      '-passlogfile', passlogFile,
      '-an',
      '-f', 'null',
      'NUL',
    ];
  }

  List<String> buildPass2Args({
    required String inputPath,
    required String outputPath,
    required EncodeSettings settings,
    required int videoBitrateKbps,
    required String passlogFile,
    required FileInfo fileInfo,
  }) {
    return [
      '-y',
      '-i', inputPath,
      ..._videoFilterArgs(settings),
      '-c:v', settings.videoCodec.ffmpegCodec,
      '-b:v', '${videoBitrateKbps}k',
      '-pass', '2',
      '-passlogfile', passlogFile,
      ..._audioArgs(settings),
      outputPath,
    ];
  }

  List<String> buildSinglePassArgs({
    required String inputPath,
    required String outputPath,
    required EncodeSettings settings,
  }) {
    return [
      '-y',
      '-i', inputPath,
      if (settings.videoEnabled) ...[
        ..._videoFilterArgs(settings),
        '-c:v', settings.videoCodec.ffmpegCodec,
        if (settings.videoCodec != VideoCodec.copy) '-crf', '23',
      ] else ...[
        '-vn',
      ],
      ..._audioArgs(settings),
      outputPath,
    ];
  }

  List<String> _videoFilterArgs(EncodeSettings settings) {
    final filter = settings.resolutionScale.scaleFilter;
    if (filter == null) return [];
    return ['-vf', filter];
  }

  List<String> _audioArgs(EncodeSettings settings) {
    if (!settings.audioEnabled) return ['-an'];
    return [
      '-c:a', settings.audioFormat.ffmpegCodec,
      if (settings.audioFormat != AudioFormat.copy &&
          settings.audioFormat != AudioFormat.flac)
        ...['-b:a', '${settings.audioBitrateKbps}k'],
    ];
  }

  static final _timeRegex = RegExp(r'time=(\d+):(\d+):(\d+\.\d+)');

  double? parseProgress(String line, double totalDurationSeconds) {
    final match = _timeRegex.firstMatch(line);
    if (match == null) return null;
    final h = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final s = double.parse(match.group(3)!);
    final elapsed = h * 3600 + m * 60 + s;
    if (totalDurationSeconds <= 0) return null;
    return (elapsed / totalDurationSeconds).clamp(0.0, 1.0);
  }

  Duration estimateRemaining(double progress, DateTime startedAt) {
    if (progress <= 0.01) return Duration.zero;
    final elapsedSecs = DateTime.now().difference(startedAt).inSeconds;
    final totalEstimated = elapsedSecs / progress;
    final remaining = totalEstimated - elapsedSecs;
    if (remaining <= 0) return Duration.zero;
    return Duration(seconds: remaining.round());
  }

  String buildOutputPath({
    required String inputPath,
    required String outputDir,
    required String suffix,
    required EncodeSettings settings,
  }) {
    final normalized = inputPath.replaceAll('\\', '/');
    final inputDir = normalized.contains('/')
        ? normalized.substring(0, normalized.lastIndexOf('/'))
        : '.';
    final filename = normalized.split('/').last;
    final stem = filename.contains('.')
        ? filename.substring(0, filename.lastIndexOf('.'))
        : filename;
    final dir = outputDir.isEmpty ? inputDir : outputDir.replaceAll('\\', '/');
    final ext = settings.videoEnabled ? 'mp4' : settings.audioFormat.extension;
    return '$dir/$stem$suffix.$ext';
  }

  String buildPasslogPath(String outputDir, String inputPath) {
    final dir = outputDir.isEmpty
        ? inputPath.replaceAll('\\', '/').split('/').reversed.skip(1).toList().reversed.join('/')
        : outputDir.replaceAll('\\', '/');
    return '$dir/cramp4_passlog';
  }

  Future<Process> spawn(List<String> args) {
    return Process.start(ffmpegPath, args);
  }
}
