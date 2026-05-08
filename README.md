# cramp4

Desktop video compression and encoding tool built with Flutter. Wraps your system installation of ffmpeg to compress, re-encode, trim and convert video files.

Runs on **Windows** and **Linux**.

<img alt="image" src="https://github.com/user-attachments/assets/1af9e0d9-5011-42af-b3ac-b47b2497adb7" />
<br>
<img alt="image" src="https://github.com/user-attachments/assets/43f69889-14d3-4c59-b9f2-1e7367e19b22" />

## Features

- **Video encoding** — encode to H.264, H.265, AV1, VP9, or copy stream
- **Target file size** — automatically calculates bitrate to hit a target MB size (2-pass encoding)
- **Resolution scaling** — downscale to 4K, 1440p, 1080p, 720p, 480p, or 360p
- **Audio settings** — choose format (AAC, MP3, Opus, FLAC) and bitrate, or mute
- **Trim** — set in/out points on a built-in video player and encode only the selected range; Space to play/pause
- **Live progress** — real-time progress bar, time remaining, and ffmpeg log output
- **Drag & drop** — drag a video file directly onto the window
- **Preserves timestamps** — output file keeps the original creation and modification dates
- **Settings** — override ffmpeg binary path, output folder, and output filename suffix
- **Shell integration** — right-click context menu entry for video files (Windows only)

## Requirements

- [ffmpeg](https://ffmpeg.org/download.html) installed and available in `PATH` (or set a custom path in Settings)

### Windows

```
winget install -e --id Gyan.FFmpeg
```

### Linux

```
sudo apt install ffmpeg        # Debian/Ubuntu
sudo dnf install ffmpeg        # Fedora
sudo pacman -S ffmpeg          # Arch
```

## Developing

### Windows

**Prerequisites:** [Flutter SDK](https://docs.flutter.dev/get-started/install/windows/desktop) with Windows desktop support enabled.

```bash
flutter pub get
flutter run -d windows
flutter build windows
```

Output: `build\windows\x64\runner\Release\`

### Linux

**Prerequisites:** [Flutter SDK](https://docs.flutter.dev/get-started/install/linux) with Linux desktop support enabled, plus build dependencies:

```bash
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev
flutter config --enable-linux-desktop
flutter pub get
flutter run -d linux
flutter build linux
```

Output: `build/linux/x64/release/bundle/`
