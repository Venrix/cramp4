# cramp4

A Windows desktop video compression and encoding tool built with Flutter. Wraps your system installation of ffmpeg to compress, re-encode, and convert video files.

## Features

- **Video encoding** — encode to H.264, H.265, AV1, VP9, or copy stream
- **Target file size** — automatically calculates bitrate to hit a target MB size (2-pass encoding)
- **Resolution scaling** — downscale to 4K, 1440p, 1080p, 720p, 480p, or 360p
- **Audio settings** — choose format (AAC, MP3, Opus, FLAC) and bitrate, or mute
- **Live progress** — real-time progress bar, time remaining, and ffmpeg log output
- **Drag & drop** — drag a video file directly onto the window
- **Settings** — override ffmpeg binary path, output folder, and output filename suffix

## Requirements

- [ffmpeg](https://ffmpeg.org/download.html) installed and available in `PATH` (or set a custom path in Settings)

## Developing

**Prerequisites:** [Flutter SDK](https://docs.flutter.dev/get-started/install/windows/desktop) with Windows desktop support enabled.

```bash
# Install dependencies
flutter pub get

# Run in debug mode
flutter run -d windows

# Build release executable
flutter build windows
```

Output: `build\windows\x64\runner\Release\cramp4.exe`
