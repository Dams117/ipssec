#!/bin/bash
LYNIS_PATH="/opt/lynis"
RAPPORT_DIR="/var/log/security-reports"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
USER=$(whoami)
RAPPORT="${RAPPORT_DIR}/lynis_${USER}_${DATE}.txt"

# Crée le dossier si nécessaire
mkdir -p "$RAPPORT_DIR"

# Lance Lynis et capture TOUT
cd "$LYNIS_PATH"
sudo ./lynis audit system > "$RAPPORT" 2>&1

# Crée le rapport trié
{
    echo "=== CRITIQUES ET WARNINGS ==="
    grep -iE "warning|\[ WARNING \]" "$RAPPORT"
    echo ""
    echo "=== SUGGESTIONS ==="
    grep -i "suggestion" "$RAPPORT"
    echo ""
    echo "=== RAPPORT COMPLET ==="
    cat "$RAPPORT"
} > "${RAPPORT}.tmp"

mv "${RAPPORT}.tmp" "$RAPPORT"
echo "Rapport sauvegardé dans : $RAPPORT"
