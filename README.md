# SequenceStitch

<p align="center">
  <img src="Assets/icon.png" width="128" height="128" alt="SequenceStitch Icon">
</p>

<p align="center">
  <strong>Convert image sequences to high-quality videos on macOS</strong>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.9-orange" alt="Swift">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

---

## Features

- 🖼️ **Drag & Drop** - Import PNG, JPEG, and PDF files
- 📂 **Folder Import** - Batch import entire folders
- 🔄 **Reorder** - Drag to rearrange sequence order
- ⏱️ **Frame Duration** - Adjustable timing per frame (0.1s - 10s)
- 🎬 **Preview** - Play sequence before exporting
- 💾 **Save Projects** - Save and reload your work

### Export Options

| Setting | Options |
|---------|---------|
| **Format** | MP4, MOV, WebM |
| **Resolution** | Original, 2x, 4x, 720p, 1080p, 4K |
| **Quality** | Low, Medium, High, Lossless |
| **Frame Rate** | 24, 30, 60 fps |
| **Encoding** | Software (libx264) or Hardware (VideoToolbox) |

## Two Versions Available

### v1 Lite (~2 MB)
Requires FFmpeg installed via Homebrew. Best for developers and users who already have FFmpeg.

```bash
# Install FFmpeg first
brew install ffmpeg

# Build v1
./build-v1-lite.sh
```

### v2 Bundled (~80 MB)
Includes FFmpeg - no external dependencies. Best for distribution to end users.

```bash
# Prepare FFmpeg (one-time setup)
mkdir -p Resources
curl -L "https://evermeet.cx/ffmpeg/getrelease/ffmpeg/7z" -o ffmpeg.7z
7z x ffmpeg.7z -oResources/ -y
rm ffmpeg.7z

# Build v2
./build-v2-bundled.sh
```

## Installation

### Build from Source

```bash
git clone https://github.com/cnrs-oguzumut/SequenceStitch.git
cd SequenceStitch

# Choose your version:
./build-v1-lite.sh      # Requires Homebrew FFmpeg
# OR
./build-v2-bundled.sh   # Self-contained (see setup above)

open build/SequenceStitch.app
```

## Usage

1. **Add Images** - Drag files onto the window or use "Open Folder"
2. **Arrange** - Drag rows to reorder, or use Sort menu
3. **Configure** - Set frame duration and export settings
4. **Preview** - Click play to preview the sequence
5. **Export** - Click "Export Video" and choose destination

## Keyboard Shortcuts

| Action | Shortcut |
|--------|----------|
| Preview Play/Pause | `Space` |
| Previous Frame | `←` |
| Next Frame | `→` |

## Tech Stack

- **SwiftUI** - Native macOS interface
- **PDFKit** - PDF rendering to PNG
- **FFmpeg** - Video encoding

## License

MIT License - see [LICENSE](LICENSE) for details.

### FFmpeg Attribution

This app uses [FFmpeg](https://ffmpeg.org/) for video encoding.

- FFmpeg is licensed under LGPL 2.1 / GPL
- Static builds from [evermeet.cx](https://evermeet.cx/ffmpeg/)
- See [FFMPEG_LICENSE.md](FFMPEG_LICENSE.md) for full details

---

<p align="center">
  Made with ❤️ for the creative community
</p>
