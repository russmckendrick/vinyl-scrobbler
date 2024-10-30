#!/bin/bash

# Exit on error
set -e

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build dist
rm -rf *.pyc
rm -rf venv

echo "✅ Cleaning complete!"