class FileInfo {
  final String path;
  final String filename;
  final Duration duration;
  final int fileSizeBytes;
  final String videoCodec;
  final String resolution;
  final int videoBitrate;
  final int audioBitrate;
  final String audioCodec;
  final double frameRate;

  const FileInfo({
    required this.path,
    required this.filename,
    required this.duration,
    required this.fileSizeBytes,
    required this.videoCodec,
    required this.resolution,
    required this.videoBitrate,
    required this.audioBitrate,
    required this.audioCodec,
    required this.frameRate,
  });

  double get durationSeconds => duration.inMilliseconds / 1000.0;

  String get durationDisplay {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m ${s}s';
    return '${m}m ${s}s';
  }

  String get fileSizeDisplay {
    if (fileSizeBytes >= 1024 * 1024 * 1024) {
      return '${(fileSizeBytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get audioBitrateDisplay {
    if (audioBitrate <= 0) return 'N/A';
    return '${(audioBitrate / 1000).round()} kbps';
  }

  String get videoCodecDisplay => videoCodec.toUpperCase();
}
