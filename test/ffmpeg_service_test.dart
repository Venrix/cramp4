import 'package:flutter_test/flutter_test.dart';

import 'package:cramp4/models/encode_settings.dart';
import 'package:cramp4/models/file_info.dart';
import 'package:cramp4/services/ffmpeg_service.dart';

void main() {
  const svc = FfmpegService();

  EncodeSettings sizeTargetSettings({AudioFormat audio = AudioFormat.copy}) =>
      EncodeSettings(
        videoEnabled: true,
        targetSizeMB: 10,
        videoCodec: VideoCodec.h264,
        resolutionScale: ResolutionScale.p720,
        audioEnabled: true,
        audioBitrateKbps: 128,
        audioFormat: audio,
      );

  const fileInfo = FileInfo(
    path: 'in.mp4',
    filename: 'in.mp4',
    duration: Duration(minutes: 20),
    fileSizeBytes: 0,
    videoCodec: 'av1',
    resolution: '2560x1440',
    videoBitrate: 0,
    audioBitrate: 200000,
    audioCodec: 'aac',
    frameRate: 60,
  );

  int seekIndex(List<String> args) => args.indexOf('-ss');
  int durationIndex(List<String> args) => args.indexOf('-t');
  int inputIndex(List<String> args) => args.indexOf('-i');

  group('hardware-accelerated input seeking', () {
    test('buildPass1Args seeks on the input side with hwaccel', () {
      final args = svc.buildPass1Args(
        inputPath: 'in.mp4',
        settings: sizeTargetSettings(),
        videoBitrateKbps: 1000,
        passlogFile: 'log',
        trimStart: const Duration(seconds: 1110),
        trimDuration: const Duration(seconds: 21),
      );

      expect(args, containsAllInOrder(['-hwaccel', 'auto']));
      expect(args.indexOf('-hwaccel'), lessThan(inputIndex(args)));
      expect(seekIndex(args), lessThan(inputIndex(args)));
      expect(durationIndex(args), lessThan(inputIndex(args)));
    });

    test('buildPass2Args seeks on the input side with hwaccel', () {
      final args = svc.buildPass2Args(
        inputPath: 'in.mp4',
        outputPath: 'out.mp4',
        settings: sizeTargetSettings(),
        videoBitrateKbps: 1000,
        passlogFile: 'log',
        fileInfo: fileInfo,
        trimStart: const Duration(seconds: 1110),
        trimDuration: const Duration(seconds: 21),
      );

      expect(args, containsAllInOrder(['-hwaccel', 'auto']));
      expect(args.indexOf('-hwaccel'), lessThan(inputIndex(args)));
      expect(seekIndex(args), lessThan(inputIndex(args)));
      expect(durationIndex(args), lessThan(inputIndex(args)));
    });

    test('buildSinglePassArgs seeks on the input side with hwaccel', () {
      final args = svc.buildSinglePassArgs(
        inputPath: 'in.mp4',
        outputPath: 'out.mp4',
        settings: sizeTargetSettings(),
        trimStart: const Duration(seconds: 1110),
        trimDuration: const Duration(seconds: 21),
      );

      expect(args, containsAllInOrder(['-hwaccel', 'auto']));
      expect(args.indexOf('-hwaccel'), lessThan(inputIndex(args)));
      expect(seekIndex(args), lessThan(inputIndex(args)));
      expect(durationIndex(args), lessThan(inputIndex(args)));
    });

    test('no -ss is emitted when trimStart is zero', () {
      final args = svc.buildSinglePassArgs(
        inputPath: 'in.mp4',
        outputPath: 'out.mp4',
        settings: sizeTargetSettings(),
      );

      expect(args, isNot(contains('-ss')));
      expect(args, containsAllInOrder(['-hwaccel', 'auto']));
    });
  });

  group('audio handling for size-targeted (two-pass) jobs', () {
    test('buildPass2Args re-encodes Copy audio as AAC at the budgeted bitrate', () {
      final args = svc.buildPass2Args(
        inputPath: 'in.mp4',
        outputPath: 'out.mp4',
        settings: sizeTargetSettings(audio: AudioFormat.copy),
        videoBitrateKbps: 1000,
        passlogFile: 'log',
        fileInfo: fileInfo,
      );

      final codecIndex = args.indexOf('-c:a');
      expect(codecIndex, greaterThanOrEqualTo(0));
      expect(args[codecIndex + 1], 'aac');
      expect(args, containsAllInOrder(['-b:a', '128k']));
    });

    test('buildPass2Args honors an explicit non-copy audio choice', () {
      final args = svc.buildPass2Args(
        inputPath: 'in.mp4',
        outputPath: 'out.mp4',
        settings: sizeTargetSettings(audio: AudioFormat.opus),
        videoBitrateKbps: 1000,
        passlogFile: 'log',
        fileInfo: fileInfo,
      );

      final codecIndex = args.indexOf('-c:a');
      expect(args[codecIndex + 1], 'libopus');
    });
  });

  group('audio handling for single-pass jobs', () {
    test('buildSinglePassArgs honors a Copy audio choice', () {
      final settings = EncodeSettings(
        videoEnabled: true,
        videoCodec: VideoCodec.h264,
        audioEnabled: true,
        audioFormat: AudioFormat.copy,
      );

      final args = svc.buildSinglePassArgs(
        inputPath: 'in.mp4',
        outputPath: 'out.mp4',
        settings: settings,
      );

      final codecIndex = args.indexOf('-c:a');
      expect(args[codecIndex + 1], 'copy');
    });
  });
}
