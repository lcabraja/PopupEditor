#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

APP_NAME="PopupEditor"
BUILD_DIR=".build/release"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
INSTALL_DIR="/Applications"

# Always build first
./build.sh

echo "==> Killing existing instances..."
pkill -x "$APP_NAME" 2>/dev/null || true
pkill -f "$INSTALL_DIR/$APP_NAME.app" 2>/dev/null || true
sleep 0.5

echo "==> Installing $APP_NAME.app to $INSTALL_DIR..."

# Remove old installation
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    echo "    Removing old installation..."
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
fi

# Copy new app
cp -R "$APP_BUNDLE" "$INSTALL_DIR/"

echo "==> Installation complete!"
echo ""
echo "==> Launching $APP_NAME..."
open "$INSTALL_DIR/$APP_NAME.app"

echo ""
echo "To start at login, add it to:"
echo "    System Settings → General → Login Items"

