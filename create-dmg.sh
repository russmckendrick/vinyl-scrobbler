#!/bin/bash

# Configuration
APP_NAME="Vinyl Scrobbler"
DMG_NAME="VinylScrobbler.dmg"
APP_PATH="$HOME/Downloads/Vinyl Scrobbler.app"
DMG_PATH="$HOME/Downloads/$DMG_NAME"
VOLUME_NAME="Vinyl Scrobbler"
TMP_DIR="/tmp/vinyl-scrobbler-dmg"
ICON_PATH="/tmp/icon.icns"

# Get the script's directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ICON_SOURCE="$SCRIPT_DIR/Vinyl Scrobbler/Assets.xcassets/AppIcon.appiconset/AppIcon.png"

# Check for required tools and install if needed
check_and_install_tools() {
    local tools=("create-dmg" "iconutil" "sips")
    local packages=("create-dmg")
    
    for i in "${!tools[@]}"; do
        if ! command -v "${tools[$i]}" &> /dev/null; then
            echo "❌ ${tools[$i]} is not installed. Installing ${packages[$i]} via Homebrew..."
            brew install "${packages[$i]}" || {
                echo "Failed to install ${packages[$i]}"
                exit 1
            }
        fi
    done
}

# Install required tools
echo "🔍 Checking for required tools..."
check_and_install_tools

# Check if the app exists
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: Could not find app at \"$APP_PATH\""
    exit 1
fi

# Create temporary directory
mkdir -p "$TMP_DIR"

# Convert PNG to ICNS
echo "🎨 Converting app icon..."
# Create iconset directory
mkdir "$TMP_DIR/icon.iconset"

# Check if icon exists
if [ ! -f "$ICON_SOURCE" ]; then
    echo "❌ Error: Could not find AppIcon.png at \"$ICON_SOURCE\""
    exit 1
fi

echo "📍 Using icon from: $ICON_SOURCE"

# Generate icon files at different sizes
for size in 16 32 64 128 256 512; do
    sips -z $size $size "$ICON_SOURCE" --out "$TMP_DIR/icon.iconset/icon_${size}x${size}.png"
    sips -z $((size*2)) $((size*2)) "$ICON_SOURCE" --out "$TMP_DIR/icon.iconset/icon_${size}x${size}@2x.png"
done

# Create icns file
iconutil -c icns "$TMP_DIR/icon.iconset" -o "$ICON_PATH"

# Remove existing DMG if it exists
if [ -f "$DMG_PATH" ]; then
    echo "🗑️  Removing existing DMG..."
    rm "$DMG_PATH"
fi

# Create dist directory and copy app
echo "📦 Preparing app for packaging..."
mkdir -p "$TMP_DIR/dist"
cp -R "$APP_PATH" "$TMP_DIR/dist/"

echo "💿 Creating custom DMG..."
create-dmg \
    --volname "$VOLUME_NAME" \
    --volicon "$ICON_PATH" \
    --window-pos 200 120 \
    --window-size 800 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 200 190 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 600 185 \
    "$DMG_PATH" \
    "$TMP_DIR/dist/"

# Clean up
echo "🧹 Cleaning up..."
rm -rf "$TMP_DIR"
rm -f "$ICON_PATH"

# Verify the DMG was created
if [ -f "$DMG_PATH" ]; then
    echo "✅ DMG created successfully at: $DMG_PATH"
    echo "📦 File size: $(du -h "$DMG_PATH" | cut -f1)"
else
    echo "❌ Error: Failed to create DMG"
    exit 1
fi 