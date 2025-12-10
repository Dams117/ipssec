#!/bin/bash
RAPPORT_DIR="/var/log/security-reports"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
USER=$(whoami)
RAPPORT="${RAPPORT_DIR}/rkhunter_${USER}_${DATE}.txt"

mkdir -p "$RAPPORT_DIR"

# Lance rkhunter et capture tout
sudo rkhunter --check --skip-keypress > "$RAPPORT" 2>&1

# Crée le rapport trié
{
    echo "=== CRITIQUES ET WARNINGS ==="
    grep -iE "warning|\[ Warning \]" "$RAPPORT"
    echo ""
    echo "=== SUGGESTIONS ==="
    grep -iE "suggestion|please inspect" "$RAPPORT"
    echo ""
    echo "=== RAPPORT COMPLET ==="
    cat "$RAPPORT"
} > "${RAPPORT}.tmp"

mv "${RAPPORT}.tmp" "$RAPPORT"
echo "Rapport sauvegardé dans : $RAPPORT"
