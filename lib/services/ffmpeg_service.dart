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
    Duration trimStart = Duration.zero,
    Duration? trimDuration,
  }) {
    return [
      '-y',
      '-hwaccel', 'auto',
      // Input-side seek: -ss/-t before -i so ffmpeg seeks (and HW-decodes) to
      // the clip instead of decoding from 0:00 and discarding. Frame-accurate
      // on the formats we target; keeps two-pass from re-scanning the whole file.
      if (trimStart > Duration.zero) ...[ '-ss', _fmtSecs(trimStart) ],
      if (trimDuration != null) ...[ '-t', _fmtSecs(trimDuration) ],
      '-i', inputPath,
      ..._videoFilterArgs(settings),
      '-c:v', settings.videoCodec.ffmpegCodec,
      '-b:v', '${videoBitrateKbps}k',
      '-pass', '1',
      '-passlogfile', passlogFile,
      '-an',
      '-f', 'null',
      Platform.isWindows ? 'NUL' : '/dev/null',
    ];
  }

  List<String> buildPass2Args({
    required String inputPath,
    required String outputPath,
    required EncodeSettings settings,
    required int videoBitrateKbps,
    required String passlogFile,
    required FileInfo fileInfo,
    Duration trimStart = Duration.zero,
    Duration? trimDuration,
  }) {
    return [
      '-y',
      '-hwaccel', 'auto',
      // Input-side seek: -ss/-t before -i so ffmpeg seeks (and HW-decodes) to
      // the clip instead of decoding from 0:00 and discarding. Frame-accurate
      // on the formats we target; keeps two-pass from re-scanning the whole file.
      if (trimStart > Duration.zero) ...[ '-ss', _fmtSecs(trimStart) ],
      if (trimDuration != null) ...[ '-t', _fmtSecs(trimDuration) ],
      '-i', inputPath,
      ..._videoFilterArgs(settings),
      '-c:v', settings.videoCodec.ffmpegCodec,
      '-b:v', '${videoBitrateKbps}k',
      '-pass', '2',
      '-passlogfile', passlogFile,
      ..._audioArgs(settings, reencodeCopyAsAac: true),
      outputPath,
    ];
  }

  List<String> buildSinglePassArgs({
    required String inputPath,
    required String outputPath,
    required EncodeSettings settings,
    Duration trimStart = Duration.zero,
    Duration? trimDuration,
  }) {
    return [
      '-y',
      '-hwaccel', 'auto',
      // Input-side seek: -ss/-t before -i so ffmpeg seeks (and HW-decodes) to
      // the clip instead of decoding from 0:00 and discarding. Frame-accurate
      // on the formats we target; keeps two-pass from re-scanning the whole file.
      if (trimStart > Duration.zero) ...[ '-ss', _fmtSecs(trimStart) ],
      if (trimDuration != null) ...[ '-t', _fmtSecs(trimDuration) ],
      '-i', inputPath,
      if (settings.videoEnabled) ...[
        ..._videoFilterArgs(settings),
        '-c:v', settings.videoCodec.ffmpegCodec,
        if (settings.videoCodec != VideoCodec.copy) ...['-crf', '23'],
      ] else ...[
        '-vn',
      ],
      ..._audioArgs(settings),
      outputPath,
    ];
  }

  static String _fmtSecs(Duration d) =>
      (d.inMilliseconds / 1000.0).toStringAsFixed(3);

  // Clock format used by {cut_from}/{cut_to}: HH.MM.SS.mmm (e.g. 00.00.06.881).
  // Dots, not colons, so the result is a legal Windows filename.
  static String _fmtClock(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    final ms = d.inMilliseconds.remainder(1000);
    return '${two(h)}.${two(m)}.${two(s)}.${ms.toString().padLeft(3, '0')}';
  }

  static String _fmtDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }

  // Strip characters illegal in Windows filenames and trailing dots/spaces.
  static String _sanitizeFilename(String name) => name
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'[ .]+$'), '');

  List<String> _videoFilterArgs(EncodeSettings settings) {
    final filter = settings.resolutionScale.scaleFilter;
    if (filter == null) return [];
    return ['-vf', filter];
  }

  List<String> _audioArgs(EncodeSettings settings,
      {bool reencodeCopyAsAac = false}) {
    if (!settings.audioEnabled) return ['-an'];
    // Two-pass/size-target jobs can't `-c:a copy`: copy + input seek fails at
    // mux, and a copied track ignores the size budget (overshooting the target).
    // Re-encode to AAC at the budgeted bitrate, which calculateVideoBitrateKbps
    // already subtracts, so the target stays accurate.
    if (reencodeCopyAsAac && settings.audioFormat == AudioFormat.copy) {
      return ['-c:a', 'aac', '-b:a', '${settings.audioBitrateKbps}k'];
    }
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
    required String prefix,
    required String suffix,
    required String template,
    required EncodeSettings settings,
    required Duration trimStart,
    required Duration trimEnd,
    required DateTime now,
    required String resLabel,
  }) {
    final normalized = inputPath.replaceAll('\\', '/');
    final inputDir = normalized.contains('/')
        ? normalized.substring(0, normalized.lastIndexOf('/'))
        : '.';
    final dir = outputDir.isEmpty ? inputDir : outputDir.replaceAll('\\', '/');
    final ext = settings.videoEnabled ? 'mp4' : settings.audioFormat.extension;
    final name = renderFilenameTemplate(
      template: template,
      inputPath: inputPath,
      prefix: prefix,
      suffix: suffix,
      ext: ext,
      trimStart: trimStart,
      trimEnd: trimEnd,
      now: now,
      resLabel: resLabel,
    );
    return '$dir/$name';
  }

  // Expands a filename template into a sanitized filename (no directory).
  // Tokens are case-insensitive; unknown {tokens} are left literal. If the
  // template has no {ext} token the extension is auto-appended, so plain
  // templates like "{prefix}{filename}{suffix}" still produce ".mp4".
  String renderFilenameTemplate({
    required String template,
    required String inputPath,
    required String prefix,
    required String suffix,
    required String ext,
    required Duration trimStart,
    required Duration trimEnd,
    required DateTime now,
    required String resLabel,
  }) {
    final filename = inputPath.replaceAll('\\', '/').split('/').last;
    final stem = filename.contains('.')
        ? filename.substring(0, filename.lastIndexOf('.'))
        : filename;
    final extWithDot = ext.startsWith('.') ? ext : '.$ext';

    final tokens = <String, String>{
      'filename': stem,
      'prefix': prefix,
      'suffix': suffix,
      'cut_from': _fmtClock(trimStart),
      'cut_to': _fmtClock(trimEnd),
      'ext': extWithDot,
      'res': resLabel,
      'date': _fmtDate(now),
      'seg_suffix': '',
    };

    final hasExt = RegExp(r'\{ext\}', caseSensitive: false).hasMatch(template);

    var name = template.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
      final value = tokens[m.group(1)!.toLowerCase()];
      return value ?? m.group(0)!;
    });

    if (!hasExt) name = '$name$extWithDot';
    name = _sanitizeFilename(name);
    if (name.isEmpty) name = _sanitizeFilename('$stem$extWithDot');
    return name;
  }

  // Returns [path] if free, else inserts " (n)" before the extension,
  // incrementing until [exists] reports the candidate is free. Prevents a new
  // export from silently overwriting an earlier one with the same name.
  String resolveOutputCollision(String path, bool Function(String) exists) {
    if (!exists(path)) return path;
    final slash = path.replaceAll('\\', '/').lastIndexOf('/');
    final dir = slash >= 0 ? path.substring(0, slash + 1) : '';
    final file = slash >= 0 ? path.substring(slash + 1) : path;
    final dot = file.lastIndexOf('.');
    final base = dot > 0 ? file.substring(0, dot) : file;
    final ext = dot > 0 ? file.substring(dot) : '';
    for (var n = 1;; n++) {
      final candidate = '$dir$base ($n)$ext';
      if (!exists(candidate)) return candidate;
    }
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

  /// Renders the command as it is invoked, for the job log. Args with spaces are
  /// quoted so the line can be copy-pasted to reproduce the run. This is for
  /// display only -- the actual spawn passes [args] verbatim, not via a shell.
  String displayCommand(List<String> args) =>
      [ffmpegPath, ...args].map((a) => a.contains(' ') ? '"$a"' : a).join(' ');
}
