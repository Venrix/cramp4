enum JobStatus { idle, pass1, pass2, encoding, done, failed, aborted }

class EncodeJob {
  final String inputPath;
  final String outputPath;
  final JobStatus status;
  final double progress;
  final Duration? remaining;
  final List<String> logLines;
  final String? errorMessage;
  final DateTime startedAt;

  const EncodeJob({
    required this.inputPath,
    required this.outputPath,
    required this.status,
    this.progress = 0.0,
    this.remaining,
    this.logLines = const [],
    this.errorMessage,
    required this.startedAt,
  });

  EncodeJob copyWith({
    String? inputPath,
    String? outputPath,
    JobStatus? status,
    double? progress,
    Duration? remaining,
    List<String>? logLines,
    String? errorMessage,
    DateTime? startedAt,
  }) {
    return EncodeJob(
      inputPath: inputPath ?? this.inputPath,
      outputPath: outputPath ?? this.outputPath,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      remaining: remaining ?? this.remaining,
      logLines: logLines ?? this.logLines,
      errorMessage: errorMessage ?? this.errorMessage,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  String get outputFilename {
    final parts = outputPath.replaceAll('\\', '/').split('/');
    return parts.last;
  }

  String get statusDisplay => switch (status) {
        JobStatus.idle => 'IDLE',
        JobStatus.pass1 => 'PASS 1',
        JobStatus.pass2 => 'PASS 2',
        JobStatus.encoding => 'ENCODING',
        JobStatus.done => 'DONE',
        JobStatus.failed => 'FAILED',
        JobStatus.aborted => 'ABORTED',
      };

  String? get remainingDisplay {
    if (remaining == null) return null;
    final m = remaining!.inMinutes;
    final s = remaining!.inSeconds.remainder(60);
    return '${m}m ${s}s';
  }
}
