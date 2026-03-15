#!/bin/bash
# install.sh — Installerar cockpit-smart plugin
# Kör som: sudo bash install.sh

set -euo pipefail

PLUGIN_DIR="/usr/share/cockpit/cockpit-smart"

echo "=== cockpit-smart installer ==="

# Kontrollera att smartmontools finns
if ! command -v smartctl &>/dev/null; then
    echo "Installerar smartmontools..."
    apt install -y smartmontools
fi

# Skapa plugin-katalog
echo "Kopierar filer till $PLUGIN_DIR..."
mkdir -p "$PLUGIN_DIR/scripts"
cp manifest.json "$PLUGIN_DIR/"
cp index.html "$PLUGIN_DIR/"
cp scripts/smart-collect.sh "$PLUGIN_DIR/scripts/"
chmod +x "$PLUGIN_DIR/scripts/smart-collect.sh"

echo ""
echo "=== Installation klar! ==="
echo "Öppna Cockpit → SMART Status i menyn."
echo "URL: https://192.168.50.8:9090/cockpit-smart/"
