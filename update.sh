#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> Updating PopupEditor..."

# Pull latest changes
if git rev-parse --git-dir > /dev/null 2>&1; then
    echo "==> Pulling latest changes..."
    git pull
fi

# Build and install
./build.sh
./install.sh

echo ""
echo "==> Update complete!"
echo "    Restart the app to use the new version."

