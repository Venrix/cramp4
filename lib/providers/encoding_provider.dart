import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../models/encode_job.dart';
import '../models/encode_settings.dart';
import '../models/file_info.dart';
import '../services/app_logger.dart';
import '../services/ffmpeg_service.dart';
import 'settings_provider.dart';

class EncodingProvider extends ChangeNotifier {
  EncodeJob? _currentJob;
  Process? _process;

  EncodingProvider();

  EncodeJob? get currentJob => _currentJob;

  bool get isEncoding {
    final s = _currentJob?.status;
    return s == JobStatus.pass1 || s == JobStatus.pass2 || s == JobStatus.encoding;
  }

  Future<void> startEncoding({
    required FileInfo fileInfo,
    required EncodeSettings settings,
    required SettingsProvider settingsConfig,
    required Duration trimStart,
    required Duration trimEnd,
  }) async {
    if (isEncoding) return;

    final trimDuration = trimEnd - trimStart;
    final effectiveDurationSecs = trimDuration.inMilliseconds > 0
        ? trimDuration.inMilliseconds / 1000.0
        : fileInfo.durationSeconds;

    final ffmpegSvc = FfmpegService(ffmpegPath: settingsConfig.effectiveFfmpegPath);
    final outputPath = ffmpegSvc.buildOutputPath(
      inputPath: fileInfo.path,
      outputDir: settingsConfig.outputDir,
      prefix: settingsConfig.outputPrefix,
      suffix: settingsConfig.outputSuffix,
      settings: settings,
    );

    final now = DateTime.now();
    _currentJob = EncodeJob(
      inputPath: fileInfo.path,
      outputPath: outputPath,
      status: JobStatus.idle,
      startedAt: now,
    );
    notifyListeners();

    try {
      final useTargetSize = settings.targetSizeMB != null &&
          settings.targetSizeMB! > 0 &&
          settings.videoEnabled &&
          settings.videoCodec != VideoCodec.copy &&
          settings.videoCodec.supportsTwoPass;

      AppLogger.info('Encoding',
          'Start (${useTargetSize ? 'two-pass' : 'single-pass'}): ${fileInfo.path} -> $outputPath');

      if (useTargetSize) {
        await _runTwoPass(fileInfo, settings, settingsConfig, outputPath, ffmpegSvc,
            trimStart, trimDuration, effectiveDurationSecs);
      } else {
        await _runSinglePass(fileInfo, settings, outputPath, ffmpegSvc,
            trimStart, trimDuration, effectiveDurationSecs);
      }

      if (_currentJob?.status == JobStatus.aborted) {
        AppLogger.warn('Encoding', 'Aborted: $outputPath');
      } else {
        AppLogger.info('Encoding', 'Completed: $outputPath');
      }
    } catch (e) {
      if (_currentJob?.status != JobStatus.aborted) {
        AppLogger.error('Encoding', 'Failed ($outputPath): $e');
        _currentJob = _currentJob?.copyWith(
          status: JobStatus.failed,
          errorMessage: e.toString(),
        );
        notifyListeners();
      } else {
        AppLogger.warn('Encoding', 'Aborted: $outputPath');
      }
    }
  }

  Future<void> _runSinglePass(
    FileInfo fileInfo,
    EncodeSettings settings,
    String outputPath,
    FfmpegService ffmpegSvc,
    Duration trimStart,
    Duration trimDuration,
    double effectiveDurationSecs,
  ) async {
    final args = ffmpegSvc.buildSinglePassArgs(
      inputPath: fileInfo.path,
      outputPath: outputPath,
      settings: settings,
      trimStart: trimStart,
      trimDuration: trimDuration,
    );

    _currentJob = _currentJob!.copyWith(
      status: JobStatus.encoding,
      startedAt: DateTime.now(),
    );
    notifyListeners();

    await _runProcess(args, effectiveDurationSecs, 0.0, 1.0, ffmpegSvc);

    if (_currentJob?.status != JobStatus.aborted) {
      await _copyFileTimestamps(fileInfo.path, outputPath);
      _currentJob = _currentJob?.copyWith(status: JobStatus.done, progress: 1.0);
      notifyListeners();
    }
  }

  Future<void> _runTwoPass(
    FileInfo fileInfo,
    EncodeSettings settings,
    SettingsProvider settingsConfig,
    String outputPath,
    FfmpegService ffmpegSvc,
    Duration trimStart,
    Duration trimDuration,
    double effectiveDurationSecs,
  ) async {
    final passlogFile = ffmpegSvc.buildPasslogPath(settingsConfig.outputDir, fileInfo.path);
    final videoBitrate = ffmpegSvc.calculateVideoBitrateKbps(
      targetSizeMB: settings.targetSizeMB!,
      durationSeconds: effectiveDurationSecs,
      audioBitrateKbps: settings.audioEnabled ? settings.audioBitrateKbps : 0,
    );

    // Pass 1
    final pass1Args = ffmpegSvc.buildPass1Args(
      inputPath: fileInfo.path,
      settings: settings,
      videoBitrateKbps: videoBitrate,
      passlogFile: passlogFile,
      trimStart: trimStart,
      trimDuration: trimDuration,
    );
    _currentJob = _currentJob!.copyWith(
      status: JobStatus.pass1,
      startedAt: DateTime.now(),
    );
    notifyListeners();

    await _runProcess(pass1Args, effectiveDurationSecs, 0.0, 0.5, ffmpegSvc);
    if (_currentJob?.status == JobStatus.aborted) {
      _cleanPasslogs(passlogFile);
      return;
    }

    // Pass 2
    final pass2Args = ffmpegSvc.buildPass2Args(
      inputPath: fileInfo.path,
      outputPath: outputPath,
      settings: settings,
      videoBitrateKbps: videoBitrate,
      passlogFile: passlogFile,
      fileInfo: fileInfo,
      trimStart: trimStart,
      trimDuration: trimDuration,
    );
    _currentJob = _currentJob!.copyWith(
      status: JobStatus.pass2,
      startedAt: DateTime.now(),
    );
    notifyListeners();

    await _runProcess(pass2Args, effectiveDurationSecs, 0.5, 1.0, ffmpegSvc);
    _cleanPasslogs(passlogFile);

    if (_currentJob?.status != JobStatus.aborted) {
      await _copyFileTimestamps(fileInfo.path, outputPath);
      _currentJob = _currentJob?.copyWith(status: JobStatus.done, progress: 1.0);
      notifyListeners();
    }
  }

  Future<void> _runProcess(
    List<String> args,
    double durationSeconds,
    double progressStart,
    double progressEnd,
    FfmpegService ffmpegSvc,
  ) async {
    final passStartedAt = DateTime.now();

    _process = await ffmpegSvc.spawn(args);

    final logLines = List<String>.from(_currentJob?.logLines ?? []);
    logLines.add('\$ ${ffmpegSvc.displayCommand(args)}');
    _currentJob = _currentJob?.copyWith(logLines: List<String>.from(logLines));
    notifyListeners();

    _process!.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
      if (_currentJob == null) return;

      // Add to log (cap at 200 lines)
      logLines.add(line);
      if (logLines.length > 200) logLines.removeAt(0);

      // Parse progress
      final rawProgress = ffmpegSvc.parseProgress(line, durationSeconds);
      if (rawProgress != null) {
        final mappedProgress = progressStart + rawProgress * (progressEnd - progressStart);
        final remaining = ffmpegSvc.estimateRemaining(rawProgress, passStartedAt);
        _currentJob = _currentJob!.copyWith(
          progress: mappedProgress,
          remaining: remaining,
          logLines: List<String>.from(logLines),
        );
        notifyListeners();
      } else {
        _currentJob = _currentJob!.copyWith(logLines: List<String>.from(logLines));
        notifyListeners();
      }
    });

    final exitCode = await _process!.exitCode;
    _process = null;

    if (exitCode != 0 && _currentJob?.status != JobStatus.aborted) {
      throw Exception('ffmpeg exited with code $exitCode');
    }
  }

  Future<void> abort() async {
    if (!isEncoding) return;
    _process?.kill();
    _process = null;

    // Delete partial output
    final outputPath = _currentJob?.outputPath;
    if (outputPath != null) {
      try {
        final f = File(outputPath);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }

    _currentJob = _currentJob?.copyWith(status: JobStatus.aborted);
    notifyListeners();
  }

  Future<void> _copyFileTimestamps(String inputPath, String outputPath) async {
    try {
      if (Platform.isWindows) {
        final src = inputPath.replaceAll("'", "''");
        final dst = outputPath.replaceAll("'", "''");
        await Process.run('powershell', [
          '-NoProfile', '-NonInteractive', '-Command',
          "\$s=Get-Item -LiteralPath '$src';"
          "\$d=Get-Item -LiteralPath '$dst';"
          "\$d.CreationTime=\$s.CreationTime;"
          "\$d.LastWriteTime=\$s.LastWriteTime",
        ]);
      } else {
        await Process.run('touch', ['-r', inputPath, outputPath]);
      }
    } catch (_) {}
  }

  void _cleanPasslogs(String passlogFile) {
    final bases = [passlogFile, '$passlogFile-0'];
    for (final base in bases) {
      for (final ext in ['', '.log', '.log.mbtree']) {
        try {
          final f = File('$base$ext');
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    }
  }
}
