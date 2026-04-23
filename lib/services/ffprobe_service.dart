import 'dart:convert';
import 'dart:io';

import '../models/file_info.dart';

class FfprobeException implements Exception {
  final String message;
  FfprobeException(this.message);
  @override
  String toString() => 'FfprobeException: $message';
}

class FfprobeService {
  final String ffprobePath;

  const FfprobeService({this.ffprobePath = 'ffprobe'});

  Future<FileInfo> probe(String inputPath) async {
    ProcessResult result;
    try {
      result = await Process.run(ffprobePath, [
        '-v', 'quiet',
        '-print_format', 'json',
        '-show_streams',
        '-show_format',
        inputPath,
      ]);
    } on ProcessException catch (e) {
      throw FfprobeException(
          'ffprobe not found or failed to run: ${e.message}. Check ffmpeg path in Settings.');
    }

    if (result.exitCode != 0) {
      throw FfprobeException(
          'ffprobe exited with code ${result.exitCode}: ${result.stderr}');
    }

    final Map<String, dynamic> json =
        jsonDecode(result.stdout as String) as Map<String, dynamic>;
    return _parseJson(json, inputPath);
  }

  FileInfo _parseJson(Map<String, dynamic> json, String path) {
    final format = json['format'] as Map<String, dynamic>? ?? {};
    final streams = (json['streams'] as List<dynamic>?) ?? [];

    final videoStream = streams.cast<Map<String, dynamic>?>().firstWhere(
          (s) => s?['codec_type'] == 'video',
          orElse: () => null,
        );
    final audioStream = streams.cast<Map<String, dynamic>?>().firstWhere(
          (s) => s?['codec_type'] == 'audio',
          orElse: () => null,
        );

    final durationSecs = double.tryParse(format['duration']?.toString() ?? '0') ?? 0;
    final fileSizeBytes = int.tryParse(format['size']?.toString() ?? '0') ?? 0;

    final videoCodec = videoStream?['codec_name']?.toString() ?? 'unknown';
    final width = videoStream?['width'] as int? ?? 0;
    final height = videoStream?['height'] as int? ?? 0;
    final resolution = (width > 0 && height > 0) ? '${width}x$height' : 'N/A';

    final videoBitrate =
        int.tryParse(videoStream?['bit_rate']?.toString() ?? '0') ??
            int.tryParse(format['bit_rate']?.toString() ?? '0') ??
            0;

    final audioCodec = audioStream?['codec_name']?.toString() ?? 'none';
    final audioBitrate =
        int.tryParse(audioStream?['bit_rate']?.toString() ?? '0') ?? 0;

    final frameRate = _parseFrameRate(videoStream?['r_frame_rate']?.toString());

    final filename = path.replaceAll('\\', '/').split('/').last;

    return FileInfo(
      path: path,
      filename: filename,
      duration: Duration(milliseconds: (durationSecs * 1000).round()),
      fileSizeBytes: fileSizeBytes,
      videoCodec: videoCodec,
      resolution: resolution,
      videoBitrate: videoBitrate,
      audioBitrate: audioBitrate,
      audioCodec: audioCodec,
      frameRate: frameRate,
    );
  }

  double _parseFrameRate(String? rFrameRate) {
    if (rFrameRate == null) return 0;
    final parts = rFrameRate.split('/');
    if (parts.length != 2) return double.tryParse(rFrameRate) ?? 0;
    final num = double.tryParse(parts[0]) ?? 0;
    final den = double.tryParse(parts[1]) ?? 1;
    if (den == 0) return 0;
    return num / den;
  }
}
