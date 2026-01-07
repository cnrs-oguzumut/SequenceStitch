# FFmpeg License Notice

**IMPORTANT: SequenceStitchBundled (v2) includes FFmpeg which is licensed under LGPL 2.1.**

This means the bundled version has different licensing obligations than the v1 Lite version.

## Your Rights

You are free to:
- Use this software for any purpose (personal or commercial)
- Modify this software
- Distribute copies of this software

## Your Obligations (LGPL Compliance)

### If you distribute SequenceStitchBundled (v2), you MUST:

1. **Include this license notice** with every distribution
2. **Provide FFmpeg source code** - Either include it or provide a written offer valid for 3 years
3. **Allow users to replace FFmpeg** - The FFmpeg binary must be replaceable by users
4. **Preserve user freedoms** - Do not add restrictions beyond what the LGPL allows
5. **Clearly identify** which parts are under LGPL (FFmpeg) vs MIT (SequenceStitch code)

### How FFmpeg Can Be Replaced

The bundled FFmpeg binary is located at:
```
SequenceStitchBundled.app/Contents/Resources/ffmpeg
```

Users can replace this with their own FFmpeg build while maintaining functionality.

## FFmpeg Source Code Availability

The bundled FFmpeg binary is version 8.0.1 built from official sources.

### Official FFmpeg Source Code:
- **Official Download**: https://ffmpeg.org/download.html
- **GitHub Repository**: https://github.com/FFmpeg/FFmpeg
- **Specific Version**: https://github.com/FFmpeg/FFmpeg/releases/tag/n8.0.1

### Pre-built Binary Source:
- The included binary is from [evermeet.cx](https://evermeet.cx/ffmpeg/)
- Build configuration is documented at the source

### Written Offer for Source Code

If you received SequenceStitchBundled in binary form and the source code was not included, you may request the complete corresponding source code for FFmpeg by contacting the distributor. This offer is valid for three years from the date of distribution.

## FFmpeg License Details

FFmpeg components are licensed under:
- **LGPL 2.1** (core libraries: libavcodec, libavformat, libavutil, etc.)
- **GPL 2.0+** (some optional components if enabled)

The bundled build uses LGPL-licensed components only.

**Full LGPL 2.1 License Text**: https://www.gnu.org/licenses/old-licenses/lgpl-2.1.html
**FFmpeg Legal Information**: https://ffmpeg.org/legal.html

## SequenceStitch License

The SequenceStitch application code (excluding FFmpeg) is licensed under the **MIT License**.

This means:
- **SequenceStitch code**: MIT (permissive, minimal restrictions)
- **FFmpeg binary**: LGPL 2.1 (copyleft, requires source availability and user replaceability)

See [LICENSE](LICENSE) file for the MIT license text.

---

## Recommendation for Distributors

**If you want to avoid LGPL compliance obligations**, use **SequenceStitch v1 (Lite)** instead. This version requires users to install FFmpeg themselves via Homebrew, completely avoiding LGPL distribution requirements while maintaining full functionality.

### Why Choose Each Version?

| Version | License | Best For |
|---------|---------|----------|
| **v1 Lite** | MIT only | Open source projects, simple distribution, avoiding LGPL |
| **v2 Bundled** | MIT + LGPL | End users, convenience, commercial apps (with LGPL compliance) |
