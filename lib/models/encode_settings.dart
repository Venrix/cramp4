enum VideoCodec { h264, h265, av1, vp9, copy }

enum AudioFormat { aac, mp3, opus, flac, copy }

enum ResolutionScale { original, k4, p1440, p1080, p720, p480, p360 }

extension VideoCodecExt on VideoCodec {
  String get displayName => switch (this) {
        VideoCodec.h264 => 'H.264 (libx264)',
        VideoCodec.h265 => 'H.265 (libx265)',
        VideoCodec.av1 => 'AV1 (libsvtav1)',
        VideoCodec.vp9 => 'VP9 (libvpx-vp9)',
        VideoCodec.copy => 'Copy (no re-encode)',
      };

  String get ffmpegCodec => switch (this) {
        VideoCodec.h264 => 'libx264',
        VideoCodec.h265 => 'libx265',
        VideoCodec.av1 => 'libsvtav1',
        VideoCodec.vp9 => 'libvpx-vp9',
        VideoCodec.copy => 'copy',
      };

  bool get supportsTwoPass => switch (this) {
        VideoCodec.h264 => true,
        VideoCodec.h265 => true,
        VideoCodec.vp9 => true,
        VideoCodec.av1 => false,
        VideoCodec.copy => false,
      };

}

VideoCodec? videoCodecFromFfprobe(String? name) => switch (name?.toLowerCase()) {
      'h264' => VideoCodec.h264,
      'hevc' => VideoCodec.h265,
      'av1' => VideoCodec.av1,
      'vp9' => VideoCodec.vp9,
      _ => null,
    };

extension AudioFormatExt on AudioFormat {
  String get displayName => switch (this) {
        AudioFormat.aac => 'AAC',
        AudioFormat.mp3 => 'MP3',
        AudioFormat.opus => 'Opus',
        AudioFormat.flac => 'FLAC',
        AudioFormat.copy => 'Copy',
      };

  String get ffmpegCodec => switch (this) {
        AudioFormat.aac => 'aac',
        AudioFormat.mp3 => 'libmp3lame',
        AudioFormat.opus => 'libopus',
        AudioFormat.flac => 'flac',
        AudioFormat.copy => 'copy',
      };

  String get extension => switch (this) {
        AudioFormat.aac => 'aac',
        AudioFormat.mp3 => 'mp3',
        AudioFormat.opus => 'opus',
        AudioFormat.flac => 'flac',
        AudioFormat.copy => 'm4a',
      };

}

AudioFormat? audioFormatFromFfprobe(String? name) => switch (name?.toLowerCase()) {
      'aac' => AudioFormat.aac,
      'mp3' => AudioFormat.mp3,
      'opus' => AudioFormat.opus,
      'flac' => AudioFormat.flac,
      _ => null,
    };

int? nearestAudioBitrate(int bitrateKbps) {
  const options = [320, 256, 192, 128, 96, 64, 32];
  if (bitrateKbps <= 0) return null;
  return options.reduce((a, b) =>
      (a - bitrateKbps).abs() <= (b - bitrateKbps).abs() ? a : b);
}

extension ResolutionScaleExt on ResolutionScale {
  String get displayName => switch (this) {
        ResolutionScale.original => 'Original',
        ResolutionScale.k4 => '4K (3840×2160)',
        ResolutionScale.p1440 => '1440p',
        ResolutionScale.p1080 => '1080p',
        ResolutionScale.p720 => '720p',
        ResolutionScale.p480 => '480p',
        ResolutionScale.p360 => '360p',
      };

  // null = no restriction (original keeps source)
  int? get maxHeight => switch (this) {
        ResolutionScale.original => null,
        ResolutionScale.k4 => 2160,
        ResolutionScale.p1440 => 1440,
        ResolutionScale.p1080 => 1080,
        ResolutionScale.p720 => 720,
        ResolutionScale.p480 => 480,
        ResolutionScale.p360 => 360,
      };

  String? get scaleFilter => switch (this) {
        ResolutionScale.original => null,
        ResolutionScale.k4 => 'scale=3840:2160:flags=lanczos:force_original_aspect_ratio=decrease',
        ResolutionScale.p1440 => 'scale=-2:1440',
        ResolutionScale.p1080 => 'scale=-2:1080',
        ResolutionScale.p720 => 'scale=-2:720',
        ResolutionScale.p480 => 'scale=-2:480',
        ResolutionScale.p360 => 'scale=-2:360',
      };
}

class EncodeSettings {
  bool videoEnabled;
  double? targetSizeMB;
  VideoCodec videoCodec;
  ResolutionScale resolutionScale;
  bool audioEnabled;
  int audioBitrateKbps;
  AudioFormat audioFormat;

  EncodeSettings({
    this.videoEnabled = true,
    this.targetSizeMB,
    this.videoCodec = VideoCodec.copy,
    this.resolutionScale = ResolutionScale.original,
    this.audioEnabled = true,
    this.audioBitrateKbps = 128,
    this.audioFormat = AudioFormat.copy,
  });
}
