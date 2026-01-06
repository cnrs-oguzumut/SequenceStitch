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

## Requirements

- macOS 14.0 (Sonoma) or later
- FFmpeg (install via Homebrew)

```bash
brew install ffmpeg
```

## Installation

### Build from Source

```bash
git clone https://github.com/cnrs-oguzumut/SequenceStitch.git
cd SequenceStitch
./build.sh
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
- **FFmpeg** - Video encoding with hardware acceleration

## License

MIT License - see [LICENSE](LICENSE) for details.

### Third-Party

This app uses [FFmpeg](https://ffmpeg.org/) for video encoding, licensed under LGPL 2.1.

---

<p align="center">
  Made with ❤️ for the creative community
</p>
