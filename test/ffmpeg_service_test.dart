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
}
