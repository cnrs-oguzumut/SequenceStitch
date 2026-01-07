#!/bin/bash

# Notarization script for SequenceStitchBundled (v2)
# Usage: ./notarize-bundled.sh

set -e

# Configuration
APP_NAME="SequenceStitchBundled"
BUILD_DIR="build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
ENTITLEMENTS="SequenceStitch.entitlements"

# Apple ID Credentials
APPLE_ID="laletaneri@gmail.com"
APP_SPECIFIC_PASSWORD="pcfl-wnws-xsch-mmdh"
TEAM_ID="UM63FN2P72"
SIGNING_IDENTITY="Developer ID Application" # Standard ID, user might need to adjust

echo "🚀 Starting Notarization Process for $APP_NAME..."

# 1. Ensure clean build
echo "Build Phase..."
./build-v2-bundled.sh

# 2. Create entitlements file if missing
if [ ! -f "$ENTITLEMENTS" ]; then
    echo "Creating entitlements file..."
    cat > "$ENTITLEMENTS" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.network.client</key>
    <true/>
    <!-- Required for FFmpeg execution -->
    <key>com.apple.security.cs.allow-jit</key>
    <true/>
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <true/>
    <key>com.apple.security.cs.disable-library-validation</key>
    <true/>
</dict>
</plist>
EOF
fi

# 3. Code Signing
echo "🔐 Signing App..."

# Sign the bundled FFmpeg binary first (deep signing)
codesign --force --options runtime --timestamp --sign "$SIGNING_IDENTITY" "$APP_BUNDLE/Contents/Resources/ffmpeg"

# Sign the entire bundle
codesign --force --options runtime --timestamp --entitlements "$ENTITLEMENTS" --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"

echo "✅ App signed successfully"

# 4. Create ZIP for upload
echo "📦 Zipping for notarization..."
/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"

# 5. Submit to Apple
echo "⬆️  Submitting to Apple Notary Service..."
echo "   (This may take a few minutes)"

xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --password "$APP_SPECIFIC_PASSWORD" \
    --team-id "$TEAM_ID" \
    --wait

echo ""
echo "🎉 Notarization submission complete!"
echo "Check the status output above. If 'Accepted', run:"
echo "xcrun stapler staple \"$APP_BUNDLE\""
