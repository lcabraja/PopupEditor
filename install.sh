#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="PopupEditor"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="/Applications"

# Check if app bundle exists
if [ ! -d "$APP_BUNDLE" ]; then
    echo "App bundle not found. Running build first..."
    ./build.sh
fi

echo "==> Installing $APP_NAME.app to $INSTALL_DIR..."

# Kill running instance if any
pkill -x "$APP_NAME" 2>/dev/null || true

# Remove old installation
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    echo "    Removing old installation..."
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

# Copy new app
cp -R "$APP_BUNDLE" "$INSTALL_DIR/"

echo "==> Installation complete!"
echo ""
echo "The app has been installed to $INSTALL_DIR/$APP_NAME.app"
echo ""
echo "To start the app:"
echo "    open /Applications/$APP_NAME.app"
echo ""
echo "To start at login, add it to:"
echo "    System Settings → General → Login Items"

