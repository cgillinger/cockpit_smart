#!/bin/bash
# install.sh — Installerar cockpit-smart plugin
# Kör som: sudo bash install.sh

set -euo pipefail

PLUGIN_DIR="/usr/share/cockpit/cockpit-smart"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CRON_FILE="/etc/cron.d/smart-history"
LOGROTATE_FILE="/etc/logrotate.d/smart-history"
HISTORY_LOG="/var/log/smart-history.json"

echo "=== cockpit-smart installer ==="

# Kontrollera att smartmontools finns
if ! command -v smartctl &>/dev/null; then
    echo "Installerar smartmontools..."
    apt install -y smartmontools
fi

# Skapa plugin-katalog och kopiera filer
echo "Kopierar filer till $PLUGIN_DIR..."
mkdir -p "$PLUGIN_DIR/scripts"

cp "$SCRIPT_DIR/manifest.json" "$PLUGIN_DIR/"
cp "$SCRIPT_DIR/index.html" "$PLUGIN_DIR/"
cp "$SCRIPT_DIR/scripts/smart-collect.sh" "$PLUGIN_DIR/scripts/"
cp "$SCRIPT_DIR/scripts/smart-history.sh" "$PLUGIN_DIR/scripts/"
chmod +x "$PLUGIN_DIR/scripts/smart-collect.sh"
chmod +x "$PLUGIN_DIR/scripts/smart-history.sh"

# Skapa historiklogg om den inte finns
if [ ! -f "$HISTORY_LOG" ]; then
    touch "$HISTORY_LOG"
    echo "Skapade $HISTORY_LOG"
fi

# Cron-jobb: daglig körning kl 08:00
echo "Installerar cron-jobb..."
cat > "$CRON_FILE" << 'EOF'
# SMART historikloggning — daglig körning
# Server vaknar 07:00, kör SMART-insamling 08:00
0 8 * * * root /usr/share/cockpit/cockpit-smart/scripts/smart-history.sh
EOF
chmod 644 "$CRON_FILE"

# Logrotate: behåll 365 dagar
echo "Installerar logrotate-konfiguration..."
cat > "$LOGROTATE_FILE" << 'EOF'
/var/log/smart-history.json {
    daily
    missingok
    notifempty
    rotate 365
    dateext
    compress
    delaycompress
    copytruncate
}
EOF
chmod 644 "$LOGROTATE_FILE"

echo ""
echo "=== Installation klar! ==="
echo "Plugin:     $PLUGIN_DIR"
echo "Historik:   $HISTORY_LOG"
echo "Cron:       $CRON_FILE (dagligen kl 08:00)"
echo "Logrotate:  $LOGROTATE_FILE (365 dagar)"
echo ""
echo "Öppna Cockpit → SMART Status i menyn."
echo "URL: https://$(hostname -I | awk '{print $1}'):9090/cockpit-smart/"
echo ""
echo "Tips: Kör en första historikloggning manuellt:"
echo "  sudo $PLUGIN_DIR/scripts/smart-history.sh"
