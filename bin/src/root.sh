#!/usr/bin/env bash
set -euo pipefail

# Script réduit pour limiter 'su' au groupe sudo et lier au sudoers
# Usage: ./restrict-su.sh

PAM_FILE="/etc/pam.d/su"
PAM_BAK="${PAM_FILE}.bak.$(date +%Y%m%d%H%M%S)"
SUDOERS_FILE="/etc/sudoers.d/allow-su"
SUDOERS_TMP="/tmp/allow-su.$$"

err() { echo "Erreur: $*" >&2; }
info() { echo "$*"; }

# Vérifier si on est root ou membre du groupe sudo ; sinon refuser
if [ "$(id -u)" -ne 0 ]; then
  CUR_USER="${SUDO_USER:-$USER}"
  if id -nG "$CUR_USER" | grep -qw sudo; then
    exec sudo -E bash "$0" "$@"
  else
    err "Vous devez être root ou membre du groupe 'sudo' pour exécuter ce script."
    exit 1
  fi
fi

# À partir d'ici on est root
info "Exécution en root"

# Installer libpam-modules si nécessaire
if ! dpkg -s libpam-modules >/dev/null 2>&1; then
  info "Installation de libpam-modules..."
  apt update
  apt install -y libpam-modules
fi

# Vérifier existence du fichier PAM
if [ ! -f "$PAM_FILE" ]; then
  err "$PAM_FILE introuvable. Abandon."
  exit 1
fi

# Confirmation utilisateur
read -rp "Souhaitez-vous limiter 'su' au groupe sudo et mettre à jour sudoers ? (o/n) " choix
case "$choix" in
  o|O) ;;
  *) info "Aucune modification effectuée."; exit 0 ;;
esac

# Sauvegarde PAM
cp -p "$PAM_FILE" "$PAM_BAK"
info "Sauvegarde PAM: $PAM_BAK"

# Nettoyer anciennes lignes et ajouter la restriction
sed -i '/pam_wheel.so/d' "$PAM_FILE" || true
sed -i '/pam_group.so/d' "$PAM_FILE" || true
PAM_LINE="auth       required   pam_wheel.so use_uid group=sudo"
if ! grep -Fxq "$PAM_LINE" "$PAM_FILE"; then
  echo "$PAM_LINE" >> "$PAM_FILE"
  info "Ligne PAM ajoutée"
else
  info "Ligne PAM déjà présente"
fi

# Préparer sudoers temporaire
cat > "$SUDOERS_TMP" <<'EOF'
# Fichier géré par restrict-su.sh
Cmnd_Alias SU = /bin/su
%sudo ALL=(ALL) SU
EOF
chmod 440 "$SUDOERS_TMP"

# Vérifier syntaxe du sudoers temporaire
if ! visudo -c -f "$SUDOERS_TMP" >/dev/null 2>&1; then
  err "Erreur de syntaxe dans le sudoers temporaire. Restauration PAM et sortie."
  cp -f "$PAM_BAK" "$PAM_FILE"
  rm -f "$SUDOERS_TMP"
  exit 1
fi

# Installer sudoers atomiquement
mv "$SUDOERS_TMP" "$SUDOERS_FILE"
chmod 440 "$SUDOERS_FILE"

# Vérifier la syntaxe globale sudoers
if ! visudo -c >/dev/null 2>&1; then
  err "Erreur après installation du sudoers. Restauration."
  rm -f "$SUDOERS_FILE"
  cp -f "$PAM_BAK" "$PAM_FILE"
  exit 1
fi

info "Opération réussie. PAM et sudoers mis à jour."
info "PAM backup: $PAM_BAK"
