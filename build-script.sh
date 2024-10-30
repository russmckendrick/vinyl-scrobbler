#!/bin/bash

# Exit on error
set -e

echo "🎵 Building Vinyl Scrobbler..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build dist
rm -rf *.pyc
rm -rf venv
test -f VinylScrobbler.dmg && rm VinylScrobbler.dmg

# Check if Python 3.11 is installed via Homebrew
PYTHON_PATH="/opt/homebrew/opt/python@3.11/bin/python3.11"
if [ ! -f "$PYTHON_PATH" ]; then
    echo "❌ Python 3.11 not found at $PYTHON_PATH"
    echo "Please install Python 3.11 via Homebrew:"
    echo "brew install python@3.11"
    exit 1
fi

# Create virtual environment with Python 3.11
echo "🔧 Creating virtual environment..."
"$PYTHON_PATH" -m venv venv

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source venv/bin/activate

# Upgrade pip and install wheel
echo "📦 Upgrading pip and installing wheel..."
python -m pip install --upgrade pip
python -m pip install wheel

# Install build dependencies first
echo "📚 Installing build dependencies..."
python -m pip install setuptools==67.6.1
python -m pip install py2app==0.28.8

# Install PyObjC dependencies first
echo "📚 Installing PyObjC..."
python -m pip install pyobjc==10.3.1

# Install other runtime dependencies
echo "📚 Installing runtime dependencies..."
python -m pip install rumps==0.4.0
python -m pip install six==1.16.0
python -m pip install python-dateutil==2.8.2
python -m pip install certifi==2024.8.30
python -m pip install charset-normalizer==3.4.0
python -m pip install idna==3.10
python -m pip install urllib3==2.2.3
python -m pip install requests==2.31.0
python -m pip install oauthlib==3.2.2
python -m pip install pylast==5.1.0
python -m pip install discogs-client==2.3.0
python -m pip install httpcore==1.0.6
python -m pip install httpx==0.27.2
python -m pip install anyio==4.6.2.post1
python -m pip install sniffio==1.3.1
python -m pip install h11==0.14.0

# Clean any previous build artifacts
echo "🧹 Cleaning build artifacts..."
rm -rf build dist
python setup.py clean --all

# Build application
echo "🏗️ Building application..."
python setup.py py2app

# Check build directory
if [ ! -d "dist/Vinyl Scrobbler.app" ]; then
    echo "❌ Build failed - app bundle not created"
    exit 1
fi

# Copy config file if it exists
if [ -f "config.json" ]; then
    echo "📄 Copying config file..."
    cp config.json "dist/Vinyl Scrobbler.app/Contents/Resources/"
fi

# Verify the binary and its dependencies
echo "🔍 Checking binary..."
otool -L "dist/Vinyl Scrobbler.app/Contents/MacOS/Vinyl Scrobbler"

echo "✅ Build complete!"
echo "📂 The application is in the dist folder"
echo ""

echo "📀 Creating DMG..."
echo ""

create-dmg \
  --volname "Vinyl Scrobbler" \
  --volicon "icon.icns" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "Vinyl Scrobbler.app" 200 190 \
  --hide-extension "Vinyl Scrobbler.app" \
  --app-drop-link 600 185 \
  "VinylScrobbler.dmg" \
  "dist/"

echo "✅ DMG complete!"
echo ""

echo "To test the application:"
echo "1. Open the dist folder"
echo "2. Right-click 'Vinyl Scrobbler.app' and select Open"
echo "3. To see any errors, run from terminal:"
echo "   ./dist/Vinyl\\ Scrobbler.app/Contents/MacOS/Vinyl\\ Scrobbler"
echo ""
echo "🔍 Debug Information:"
echo "Python version: $(python --version)"
echo "pip version: $(pip --version)"
echo "setuptools version: $(pip show setuptools | grep Version)"
echo "py2app version: $(pip show py2app | grep Version)"
echo "pyobjc version: $(pip show pyobjc | grep Version)"