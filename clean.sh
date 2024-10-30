#!/bin/bash

# Exit on error
set -e

# Clean previous builds
echo "🧹 Cleaning previous builds..."
rm -rf build dist .eggs venv
rm -rf *.pyc

echo "✅ Cleaning complete!"