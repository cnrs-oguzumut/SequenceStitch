# Building Universal FFmpeg Binary for SequenceStitch

## Current Issue
The bundled FFmpeg is x86_64 only, which causes issues when running in a sandboxed environment on Apple Silicon Macs.

## Quick Fix (Current)
Added `com.apple.security.cs.allow-dyld-environment-variables` entitlement to allow Rosetta 2 execution.

## Better Solution: Universal Binary

### Option 1: Download Pre-built Universal Binary
Visit https://evermeet.cx/ffmpeg/ and download the universal (arm64 + x86_64) build.

### Option 2: Build from Source (Using Homebrew FFmpeg)
If you have Homebrew FFmpeg installed, it's likely already arm64:

```bash
# Check your Homebrew FFmpeg
lipo -info /opt/homebrew/bin/ffmpeg

# If it's arm64, create a universal binary by combining with x86_64 version
# First get x86_64 version (you may need to build or download it)
# Then use lipo to combine:
lipo -create /path/to/x86_64/ffmpeg /opt/homebrew/bin/ffmpeg -output ffmpeg_universal
```

### Option 3: Build Both Architectures from Source

```bash
# Build for arm64
./configure --arch=arm64 --enable-cross-compile --prefix=/tmp/ffmpeg-arm64 \
    --disable-doc --disable-debug --enable-gpl --enable-libx264 --enable-libvpx
make clean
make -j8
make install

# Build for x86_64
./configure --arch=x86_64 --prefix=/tmp/ffmpeg-x86_64 \
    --disable-doc --disable-debug --enable-gpl --enable-libx264 --enable-libvpx
make clean
make -j8
make install

# Combine into universal binary
lipo -create /tmp/ffmpeg-arm64/bin/ffmpeg /tmp/ffmpeg-x86_64/bin/ffmpeg \
    -output ffmpeg_universal

# Verify
lipo -info ffmpeg_universal
# Should output: "Architectures in the fat file: ffmpeg_universal are: x86_64 arm64"
```

## After Building/Downloading
1. Replace the current FFmpeg in your build script
2. Code sign the new binary:
   ```bash
   codesign --force --sign "3rd Party Mac Developer Application: Lale Taneri (UM63FN2P72)" \
       --options runtime Resources/ffmpeg_universal
   ```
3. Update your build script to use the universal binary

## Verify
```bash
lipo -info dist/SequenceStitch.app/Contents/Resources/ffmpeg
# Should show: "Architectures in the fat file: ffmpeg are: x86_64 arm64"
```
