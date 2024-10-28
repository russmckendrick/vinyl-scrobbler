#!/bin/bash

# Exit on error
set -e

echo "🎵 Building Vinyl Scrobbler..."

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build dist
rm -rf *.pyc
rm -rf venv

# Create virtual environment with Python 3.11
echo "🔧 Creating virtual environment..."
if command -v python3.11 &> /dev/null; then
    python3.11 -m venv venv
else
    python -m venv venv
fi

# Activate virtual environment
echo "🔌 Activating virtual environment..."
source venv/bin/activate

# Upgrade pip and install wheel
echo "📦 Upgrading pip and installing wheel..."
pip install --upgrade pip
pip install wheel

# Install dependencies
echo "📚 Installing dependencies..."
pip install rumps==0.4.0
pip install python-dateutil==2.8.2
pip install pylast==5.1.0
pip install discogs-client==2.3.0
pip install requests==2.31.0
pip install -U py2app

# Clean previous builds again (just to be safe)
echo "🧹 Cleaning previous builds..."
rm -rf build dist
python setup.py clean build

# Build in alias mode
echo "🏗️ Building application..."
python setup.py py2app -A

# Copy config file if it exists
if [ -f "config.json" ]; then
    echo "📄 Copying config file..."
    cp config.json "dist/Vinyl Scrobbler.app/Contents/Resources/"
fi

echo "✅ Build complete!"
echo "📂 The application is in the dist folder"
echo ""
echo "To test the application:"
echo "1. Open the dist folder"
echo "2. Right-click 'Vinyl Scrobbler.app' and select Open"