# FFmpeg License Notice

SequenceStitch uses FFmpeg for video encoding.

## FFmpeg License

FFmpeg is licensed under the GNU Lesser General Public License (LGPL) version 2.1 or later. Some optional components are licensed under the GNU General Public License (GPL) version 2 or later.

For full license details, see:
- https://ffmpeg.org/legal.html
- https://www.gnu.org/licenses/lgpl-2.1.html

## Static Build Attribution

The bundled FFmpeg static build (v2) is provided by:
- **evermeet.cx** - https://evermeet.cx/ffmpeg/

## Your Obligations

If you distribute SequenceStitch with the bundled FFmpeg (v2), you must:
1. Include this license notice
2. Provide access to the FFmpeg source code upon request
3. Not claim FFmpeg as your own work

## Building Without Bundled FFmpeg

For the v1 (lite) version, users install FFmpeg themselves:
```bash
brew install ffmpeg
```

This approach means you are not distributing FFmpeg, avoiding LGPL distribution requirements.
