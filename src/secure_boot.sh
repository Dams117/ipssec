#!/usr/bin/env bash
set -euo pipefail

# =========================
# secure_boot.sh
# Durcissement GRUB :
# - superuser
# - mot de passe PBKDF2
# - permissions strictes sur grub.cfg
#
# Interactif par défaut (demande confirmation)
# Options :
#   --yes                 : exécute sans demander confirmation
#   --user <name>         : définit le superuser GRUB
#   --hash <pbkdf2_hash>  : fournit un hash PBKDF2 existant
# =========================

GRUB_USER_DEFAULT="admin"
GRUB_HASH_DEFAULT=""  # Laisse vide pour forcer un choix interactif

GRUB_USERS_FILE="/etc/grub.d/01_users"
GRUB_CFG="/boot/grub/grub.cfg"

ASSUME_YES=0
GRUB_USER=""
GRUB_HASH=""

log() {
  echo "[secure_boot] $*"
}

usage() {
  cat <<'EOF'
Usage:
  sudo ./secure_boot.sh [--yes] [--user <name>] [--hash <pbkdf2_hash>]

Comportement:
  - Par défaut, le script est interactif et demande confirmation.
  - Si --hash n'est pas fourni, le script proposera de générer un hash avec grub-mkpasswd-pbkdf2.

Exemples:
  sudo ./secure_boot.sh
  sudo ./secure_boot.sh --user admin
  sudo ./secure_boot.sh --hash 'grub.pbkdf2.sha512....'
  sudo ./secure_boot.sh --yes --user admin --hash 'grub.pbkdf2.sha512....'
EOF
}

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    log "Erreur: ce script doit être exécuté en root (sudo)."
    exit 1
  fi
}

confirm() {
  local prompt="${1:-Continuer ?}"
  local answer=""
  if [[ "$ASSUME_YES" -eq 1 ]]; then
    return 0
  fi
  while true; do
    read -r -p "${prompt} [y/N] " answer || true
    case "${answer,,}" in
      y|yes|o|oui) return 0 ;;
      n|no|non|"") return 1 ;;
      *) echo "Réponse invalide. Tape y ou n." ;;
    esac
  done
}

backup_file_if_exists() {
  local f="$1"
  if [[ -f "$f" ]]; then
    local ts
    ts="$(date +%Y%m%d_%H%M%S)"
    cp -a "$f" "${f}.bak_${ts}"
    log "Sauvegarde créée: ${f}.bak_${ts}"
  fi
}

ask_grub_user() {
  if [[ -n "$GRUB_USER" ]]; then
    return 0
  fi

  local input=""
  read -r -p "Nom du superuser GRUB [${GRUB_USER_DEFAULT}]: " input || true
  GRUB_USER="${input:-$GRUB_USER_DEFAULT}"
}

generate_hash_interactive() {
  log "Génération d'un hash PBKDF2 via grub-mkpasswd-pbkdf2"
  # La commande va demander le mot de passe + confirmation.
  local out=""
  out="$(grub-mkpasswd-pbkdf2)"
  # Extraction robuste du hash
  GRUB_HASH="$(echo "$out" | awk -F' is ' '/PBKDF2 hash of your password is/ {print $2}' | tail -n 1)"

  if [[ -z "$GRUB_HASH" ]]; then
    log "Erreur: impossible d'extraire le hash PBKDF2."
    exit 1
  fi
}

ask_grub_hash() {
  if [[ -n "$GRUB_HASH" ]]; then
    return 0
  fi
  if [[ -n "$GRUB_HASH_DEFAULT" ]]; then
    GRUB_HASH="$GRUB_HASH_DEFAULT"
    return 0
  fi

  log "Aucun hash fourni."
  echo "Choisis une option :"
  echo "  1) Générer un nouveau hash PBKDF2 maintenant"
  echo "  2) Coller un hash PBKDF2 existant"
  echo "  3) Annuler"

  local choice=""
  while true; do
    read -r -p "Ton choix [1/2/3]: " choice || true
    case "$choice" in
      1)
        generate_hash_interactive
        break
        ;;
      2)
        read -r -p "Colle ton hash PBKDF2: " GRUB_HASH || true
        if [[ -z "$GRUB_HASH" ]]; then
          echo "Hash vide. Recommence."
        else
          break
        fi
        ;;
      3|"")
        log "Annulé par l'utilisateur."
        exit 0
        ;;
      *)
        echo "Choix invalide."
        ;;
    esac
  done
}

write_grub_users_file() {
  log "Configuration du superuser GRUB dans ${GRUB_USERS_FILE}"

  backup_file_if_exists "${GRUB_USERS_FILE}"

  cat > "${GRUB_USERS_FILE}" <<'EOF'
#!/bin/sh
set -e

cat <<EOT
set superusers="__GRUB_USER__"
password_pbkdf2 __GRUB_USER__ __GRUB_HASH__
EOT
EOF

  sed -i \
    -e "s|__GRUB_USER__|${GRUB_USER}|g" \
    -e "s|__GRUB_HASH__|${GRUB_HASH}|g" \
    "${GRUB_USERS_FILE}"

  chown root:root "${GRUB_USERS_FILE}"
  chmod 755 "${GRUB_USERS_FILE}"

  log "Fichier ${GRUB_USERS_FILE} mis à jour."
}

regenerate_grub() {
  log "Regénération de la configuration GRUB"

  if command -v update-grub >/dev/null 2>&1; then
    update-grub
  elif command -v grub-mkconfig >/dev/null 2>&1; then
    grub-mkconfig -o "${GRUB_CFG}"
  else
    log "Erreur: impossible de trouver update-grub ou grub-mkconfig."
    exit 1
  fi

  log "GRUB regénéré."
}

harden_grub_cfg_perms() {
  if [[ -f "${GRUB_CFG}" ]]; then
    chown root:root "${GRUB_CFG}"
    chmod 600 "${GRUB_CFG}"
    log "Permissions durcies sur ${GRUB_CFG} (root:root, 600)."
  else
    log "Erreur: ${GRUB_CFG} introuvable après génération."
    exit 1
  fi
}

quick_checks() {
  log "Vérifications rapides"

  if grep -q "set superusers=\"${GRUB_USER}\"" "${GRUB_USERS_FILE}"; then
    log "OK: superusers présent dans ${GRUB_USERS_FILE}"
  else
    log "ERREUR: superusers absent dans ${GRUB_USERS_FILE}"
    exit 1
  fi

  if grep -q "password_pbkdf2 ${GRUB_USER}" "${GRUB_USERS_FILE}"; then
    log "OK: password_pbkdf2 présent dans ${GRUB_USERS_FILE}"
  else
    log "ERREUR: password_pbkdf2 absent dans ${GRUB_USERS_FILE}"
    exit 1
  fi

  if grep -q "set superusers=\"${GRUB_USER}\"" "${GRUB_CFG}"; then
    log "OK: superusers détecté dans grub.cfg"
  else
    log "ERREUR: superusers non détecté dans grub.cfg"
    exit 1
  fi

  if grep -q "password_pbkdf2 ${GRUB_USER}" "${GRUB_CFG}"; then
    log "OK: password_pbkdf2 détecté dans grub.cfg"
  else
    log "ERREUR: password_pbkdf2 non détecté dans grub.cfg"
    exit 1
  fi

  local perms
  perms="$(stat -c "%a %U %G" "${GRUB_CFG}")"
  if [[ "${perms}" == "600 root root" ]]; then
    log "OK: permissions ${GRUB_CFG} = ${perms}"
  else
    log "Attention: permissions ${GRUB_CFG} inattendues (${perms})"
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y)
        ASSUME_YES=1
        shift
        ;;
      --user)
        GRUB_USER="${2:-}"
        shift 2
        ;;
      --hash)
        GRUB_HASH="${2:-}"
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *)
        log "Argument inconnu: $1"
        usage
        exit 1
        ;;
    esac
  done
}

main() {
  parse_args "$@"
  require_root

  log "Ce script va :"
  echo "  - Créer/mettre à jour ${GRUB_USERS_FILE}"
  echo "  - Définir un superuser GRUB"
  echo "  - Ajouter un mot de passe PBKDF2"
  echo "  - Régénérer ${GRUB_CFG}"
  echo "  - Appliquer des permissions strictes (600 root:root)"
  echo

  if ! confirm "Souhaites-tu appliquer ce durcissement GRUB ?"; then
    log "Annulé par l'utilisateur."
    exit 0
  fi

  ask_grub_user
  ask_grub_hash

  log "Superuser choisi: ${GRUB_USER}"
  log "Hash PBKDF2: défini"

  if ! confirm "Confirmer l'écriture de ${GRUB_USERS_FILE} et la régénération de GRUB ?"; then
    log "Annulé par l'utilisateur."
    exit 0
  fi

  write_grub_users_file
  regenerate_grub
  harden_grub_cfg_perms
  quick_checks

  log "Terminé."
  log "Rappel: le mot de passe sera requis pour éditer les entrées GRUB ou accéder à la console."
}

main "$@"
