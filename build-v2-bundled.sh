#!/bin/bash

# Build script for SequenceStitch v2 (Bundled) - includes FFmpeg

set -e

APP_NAME="SequenceStitch"
VERSION="2.0.0"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building $APP_NAME v$VERSION (Bundled - includes FFmpeg)..."

# Check if bundled FFmpeg exists
if [ ! -f "Resources/ffmpeg" ]; then
    echo ""
    echo "⚠️  Bundled FFmpeg not found at Resources/ffmpeg"
    echo ""
    echo "To prepare FFmpeg for bundling, run:"
    echo "  mkdir -p Resources"
    echo "  cp /opt/homebrew/bin/ffmpeg Resources/ffmpeg"
    echo ""
    echo "Then run this script again."
    exit 1
fi

# Build release binary
swift build -c release

echo "Creating app bundle..."

# Create directory structure
rm -rf "$APP_BUNDLE"
mkdir -p "$BUILD_DIR"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy executable from Swift build output
cp ".build/release/$APP_NAME" "$MACOS/$APP_NAME"

# Copy bundled FFmpeg
echo "Bundling FFmpeg..."
cp "Resources/ffmpeg" "$RESOURCES/ffmpeg"
chmod +x "$RESOURCES/ffmpeg"
echo "✓ FFmpeg bundled"

# Create Info.plist
cat > "$CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.sequencestitch.app</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>
            <string>SequenceStitch Project</string>
            <key>CFBundleTypeExtensions</key>
            <array>
                <string>seqstitch</string>
            </array>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
        </dict>
    </array>
</dict>
</plist>
EOF

# Convert icon.png to icns
echo "Creating app icon..."
ICON_SOURCE="Assets/icon.png"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"

if [ -f "$ICON_SOURCE" ]; then
    mkdir -p "$ICONSET_DIR"
    
    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" 2>/dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" 2>/dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" 2>/dev/null
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" 2>/dev/null
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" 2>/dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" 2>/dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" 2>/dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" 2>/dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" 2>/dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" 2>/dev/null
    
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES/AppIcon.icns"
    rm -rf "$ICONSET_DIR"
    
    echo "✓ App icon created"
fi

# Show bundle size
BUNDLE_SIZE=$(du -sh "$APP_BUNDLE" | cut -f1)

echo ""
echo "✅ Build complete!"
echo "📦 App bundle: $APP_BUNDLE ($BUNDLE_SIZE)"
echo "🎬 FFmpeg is bundled - no external dependencies!"
echo ""
echo "To open: open $APP_BUNDLE"
