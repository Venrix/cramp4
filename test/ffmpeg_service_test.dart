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

  group('displayCommand', () {
    test('prepends the ffmpeg path and quotes args containing spaces', () {
      const svc = FfmpegService(ffmpegPath: 'ffmpeg');
      final cmd = svc.displayCommand([
        '-i',
        'C:/Shadowplay Videos/clip.mp4',
        '-c:v',
        'libx264',
        'C:/out/clip_cramp4.mp4',
      ]);

      expect(
        cmd,
        'ffmpeg -i "C:/Shadowplay Videos/clip.mp4" -c:v libx264 C:/out/clip_cramp4.mp4',
      );
    });

    test('quotes the ffmpeg path itself when it contains spaces', () {
      const svc = FfmpegService(ffmpegPath: r'C:\Program Files\ffmpeg\ffmpeg.exe');
      final cmd = svc.displayCommand(['-version']);

      expect(cmd, r'"C:\Program Files\ffmpeg\ffmpeg.exe" -version');
    });
  });

  group('video codec handling for single-pass jobs', () {
    test('buildSinglePassArgs omits -crf and its value for a Copy video codec', () {
      final settings = EncodeSettings(
        videoEnabled: true,
        videoCodec: VideoCodec.copy,
        audioEnabled: true,
        audioFormat: AudioFormat.copy,
      );

      final args = svc.buildSinglePassArgs(
        inputPath: 'in.mp4',
        outputPath: 'out.mp4',
        settings: settings,
      );

      expect(args, isNot(contains('-crf')));
      // The orphaned '23' (CRF value) must not leak in as a positional arg —
      // ffmpeg would treat it as an output filename.
      expect(args, isNot(contains('23')));
      final videoCodecIndex = args.indexOf('-c:v');
      expect(args[videoCodecIndex + 1], 'copy');
      expect(args[videoCodecIndex + 2], '-c:a');
    });

    test('buildSinglePassArgs emits -crf 23 together for a re-encode codec', () {
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

      expect(args, containsAllInOrder(['-crf', '23']));
    });
  });

  group('filename template', () {
    String render(
      String template, {
      String inputPath = 'clip.mp4',
      String ext = 'mp4',
      Duration trimStart = Duration.zero,
      Duration trimEnd = Duration.zero,
      String resLabel = '',
    }) =>
        svc.renderFilenameTemplate(
          template: template,
          inputPath: inputPath,
          ext: ext,
          trimStart: trimStart,
          trimEnd: trimEnd,
          now: DateTime(2026, 6, 15),
          resLabel: resLabel,
        );

    test('default template auto-appends the extension', () {
      expect(
        render('{filename}', inputPath: 'C:/vids/clip.mp4'),
        'clip.mp4',
      );
    });

    test('LosslessCut template formats cut times as HH.MM.SS.mmm', () {
      expect(
        render('{filename}-{cut_from}-{cut_to}{seg_suffix}{ext}',
            trimStart: const Duration(milliseconds: 6881),
            trimEnd: const Duration(milliseconds: 82640)),
        'clip-00.00.06.881-00.01.22.640.mp4',
      );
    });

    test('tokens are case-insensitive', () {
      expect(render('{FILENAME}{EXT}', inputPath: 'clip.mkv'), 'clip.mp4');
    });

    test('explicit {ext} is not double-appended', () {
      final name = render('{filename}{ext}');
      expect(name, 'clip.mp4');
      expect('.mp4'.allMatches(name).length, 1);
    });

    test('illegal characters are sanitized', () {
      expect(render(r'a:b<c>d|e{filename}'), 'a_b_c_d_eclip.mp4');
    });

    test('{res} expands to the resolution label', () {
      expect(render('{filename}_{res}', resLabel: '720p'), 'clip_720p.mp4');
    });

    test('{date} expands to YYYY-MM-DD', () {
      expect(render('{filename}_{date}'), 'clip_2026-06-15.mp4');
    });

    test('unknown tokens are left literal', () {
      expect(render('{filename}{unknown}'), 'clip{unknown}.mp4');
    });
  });

  group('output collision', () {
    test('returns the path unchanged when nothing exists', () {
      expect(
        svc.resolveOutputCollision('C:/out/clip.mp4', (_) => false),
        'C:/out/clip.mp4',
      );
    });

    test('appends an incrementing (n) suffix on collision', () {
      final taken = {'C:/out/clip.mp4', 'C:/out/clip (1).mp4'};
      expect(
        svc.resolveOutputCollision('C:/out/clip.mp4', taken.contains),
        'C:/out/clip (2).mp4',
      );
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
