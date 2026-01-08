#!/bin/bash

# Build script for SequenceStitch App Store submission
# Produces a sandboxed, signed .pkg ready for Transporter upload

set -e

APP_NAME="SequenceStitch"
EXECUTABLE_NAME="SequenceStitch"
VERSION="1.0.0"
BUILD_NUMBER="1"
BUNDLE_ID="com.sequencestitch.app"
BUILD_DIR="dist"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# Your Apple Developer Team ID and certificates
TEAM_ID="UM63FN2P72"
SIGNING_IDENTITY="3rd Party Mac Developer Application: Lale Taneri (UM63FN2P72)"
INSTALLER_IDENTITY="3rd Party Mac Developer Installer: Lale Taneri (UM63FN2P72)"

echo "🏪 Building $APP_NAME v$VERSION for Mac App Store..."

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
echo "📦 Building release binary..."
swift build -c release

echo "Creating app bundle..."

# Create directory structure
rm -rf "$APP_BUNDLE"
mkdir -p "$BUILD_DIR"
mkdir -p "$MACOS"
mkdir -p "$RESOURCES"

# Copy executable
cp ".build/release/$EXECUTABLE_NAME" "$MACOS/$APP_NAME"

# Copy bundled FFmpeg
echo "📦 Bundling FFmpeg..."
cp "Resources/ffmpeg" "$RESOURCES/ffmpeg"
chmod +x "$RESOURCES/ffmpeg"

# Copy LGPL license for FFmpeg
if [ -f "FFMPEG_LICENSE.md" ]; then
    cp "FFMPEG_LICENSE.md" "$RESOURCES/FFMPEG_LICENSE.md"
fi
echo "✓ FFmpeg bundled"

# Create Info.plist for App Store
cat > "$CONTENTS/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>SequenceStitch</string>
    <key>CFBundleVersion</key>
    <string>$BUILD_NUMBER</string>
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
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.video</string>
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

# Sign the app with App Store entitlements
echo "🔐 Signing for App Store..."

# First sign the FFmpeg binary
codesign --force --options runtime \
    --sign "$SIGNING_IDENTITY" \
    --entitlements "SequenceStitchAppStore.entitlements" \
    "$RESOURCES/ffmpeg"

# Then sign the main app
codesign --force --options runtime \
    --sign "$SIGNING_IDENTITY" \
    --entitlements "SequenceStitchAppStore.entitlements" \
    "$APP_BUNDLE"

echo "✅ App signed for App Store"

# Create installer package (.pkg)
echo "📦 Creating installer package..."
PKG_PATH="$BUILD_DIR/$APP_NAME.pkg"

productbuild --component "$APP_BUNDLE" /Applications \
    --sign "$INSTALLER_IDENTITY" \
    "$PKG_PATH"

echo "✅ Installer package created"

# Verify
echo ""
echo "🔍 Verifying package..."
pkgutil --check-signature "$PKG_PATH"

echo ""
echo "✅ App Store build complete!"
echo ""
echo "📦 Package: $PKG_PATH"
echo ""
echo "Next steps:"
echo "  1. Open Transporter app"
echo "  2. Drag $PKG_PATH into Transporter"
echo "  3. Click 'Deliver' to upload to App Store Connect"
echo ""
