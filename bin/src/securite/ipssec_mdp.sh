#!/bin/bash
##############################################
# Module PAM - Politique de mots de passe
# Cible : Ubuntu Server / Ubuntu Desktop
# Installation auto de libpam-pwquality
# Auteurs : Alexandre Ducret & Yannis Levy
##############################################

set -e  # arrêter en cas d’erreur

PAM_PASSWORD_FILE="/etc/pam.d/common-password"
PWQUALITY_CONF="/etc/security/pwquality.conf"
LOGIN_DEFS_FILE="/etc/login.defs"

############################################################
# 🔍 Vérifier et installer libpam-pwquality si nécessaire
############################################################
install_pwquality_if_missing() {
    if [ -f "/lib/security/pam_pwquality.so" ] \
       || [ -f "/lib/x86_64-linux-gnu/security/pam_pwquality.so" ] \
       || [ -f "/usr/lib/x86_64-linux-gnu/security/pam_pwquality.so" ]; then
        echo "[PAM] pam_pwquality déjà installé."
        return 0
    fi

    echo "[PAM] pam_pwquality n'est pas installé. Installation..."

    if ! command -v apt >/dev/null 2>&1; then
        echo "[ERREUR] Ce script est conçu pour Ubuntu/Debian uniquement."
        exit 1
    fi

    sudo apt update -y
    sudo apt install -y libpam-pwquality

    echo "[PAM] Installation terminée de libpam-pwquality."
}

backup_file() {
    local f="$1"
    if [ -f "$f" ] && [ ! -f "${f}.ipssec.bak" ]; then
        cp "$f" "${f}.ipssec.bak"
        echo "[PAM] Sauvegarde créée : ${f}.ipssec.bak"
    fi
}

set_pwq_option() {
    local key="$1"
    local value="$2"

    if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$PWQUALITY_CONF" 2>/dev/null; then
        sudo sed -i "s/^[[:space:]]*${key}[[:space:]]*=.*/${key} = ${value}/" "$PWQUALITY_CONF"
    else
        echo "${key} = ${value}" | sudo tee -a "$PWQUALITY_CONF" >/dev/null
    fi
}

set_login_defs_option() {
    local key="$1"
    local value="$2"

    if grep -qE "^[[:space:]]*${key}[[:space:]]+" "$LOGIN_DEFS_FILE"; then
        sudo sed -i "s/^[[:space:]]*${key}[[:space:]]\+.*/${key}   ${value}/" "$LOGIN_DEFS_FILE"
    else
        echo "${key}   ${value}" | sudo tee -a "$LOGIN_DEFS_FILE" >/dev/null
    fi
}

set_remember_option() {
    local remember="$1"

    if grep -qE '^[[:space:]]*password[[:space:]]+.*pam_unix\.so' "$PAM_PASSWORD_FILE"; then
        sudo sed -i 's/\(pam_unix\.so[^#]*\)remember=[0-9]\+/\1/' "$PAM_PASSWORD_FILE"

        if [ "$remember" -gt 0 ]; then
            sudo sed -i "s/\(pam_unix\.so[^#]*\)$/\1 remember=${remember}/" "$PAM_PASSWORD_FILE"
        fi
    fi
}

ensure_pam_pwquality_line() {
    if grep -q "pam_pwquality.so" "$PAM_PASSWORD_FILE"; then
        echo "[PAM] pam_pwquality déjà présent dans common-password."
        return
    fi

    echo "[PAM] Ajout de la règle pam_pwquality..."

    sudo awk '
        /pam_unix\.so/ && !done {
            print "password   requisite   pam_pwquality.so retry=3"
            done=1
        }
        { print }
    ' "$PAM_PASSWORD_FILE" > "${PAM_PASSWORD_FILE}.tmp" && sudo mv "${PAM_PASSWORD_FILE}.tmp" "$PAM_PASSWORD_FILE"
}

############################################################
# APPLIQUER UNE POLITIQUE
############################################################
harden_pam_passwords() {
    local mode="$1"
    echo "[PAM] Application mode : $mode"

    case "$mode" in
        strict)
            minlen=12; difok=4; ucredit=-1; lcredit=-1; dcredit=-1; ocredit=-1
            remember=5; pass_max=90; pass_min=1; pass_warn=7 ;;
        medium)
            minlen=10; difok=2; ucredit=-1; lcredit=-1; dcredit=-1; ocredit=0
            remember=3; pass_max=120; pass_min=1; pass_warn=7 ;;
        weak)
            minlen=8; difok=1; ucredit=0; lcredit=0; dcredit=0; ocredit=0
            remember=0; pass_max=365; pass_min=0; pass_warn=7 ;;
    esac

    echo "[PAM] Sauvegardes..."
    backup_file "$PWQUALITY_CONF"
    backup_file "$LOGIN_DEFS_FILE"
    backup_file "$PAM_PASSWORD_FILE"

    install_pwquality_if_missing

    echo "[PAM] Configuration de pwquality..."
    set_pwq_option "minlen" "$minlen"
    set_pwq_option "difok" "$difok"
    set_pwq_option "ucredit" "$ucredit"
    set_pwq_option "lcredit" "$lcredit"
    set_pwq_option "dcredit" "$dcredit"
    set_pwq_option "ocredit" "$ocredit"
    set_pwq_option "retry" "3"
    set_pwq_option "enforce_for_root" "1"

    ensure_pam_pwquality_line

    echo "[PAM] Mise en place de l'historique (remember=$remember)..."
    set_remember_option "$remember"

    echo "[PAM] Mise à jour de /etc/login.defs..."
    set_login_defs_option "PASS_MAX_DAYS" "$pass_max"
    set_login_defs_option "PASS_MIN_DAYS" "$pass_min"
    set_login_defs_option "PASS_WARN_AGE" "$pass_warn"

    echo "[PAM] Politique appliquée avec succès."
}

############################################################
# MENU UTILISATEUR
############################################################
show_menu() {
    echo "====================================="
    echo "    MODULE PAM - MOTS DE PASSE"
    echo "    Ubuntu Server (IPSSEC)"
    echo "    Alexandre Ducret & Yannis Levy"
    echo "====================================="
    echo "1) Politique STRICTE (Fortement recomandée)"
    echo "   -->   long min 12 character, 1 Maj. , 1 chiffre , 1 car. spec. , diff des 5 derniers mdp, valable 90 jours"
    echo " " 
    echo "2) Politique MOYENNE"
    echo "   -->   long min 10 character, 1 Maj. , 1 chiffre , diff des 3 derniers mdp, valable 120 jours"
    echo " " 
    echo "3) Politique FAIBLE (Non recommandée)" 
    echo "   -->   long min 8 character, valable 365 jours"
    echo " " 
    echo "4) Quitter"
    read -rp "Votre choix : " choice

    case "$choice" in
        1) harden_pam_passwords strict ;;
        2) harden_pam_passwords medium ;;
        3) harden_pam_passwords weak ;;
        4) exit 0 ;;
        *) show_menu ;;
    esac
}

echo "[IPSSEC] Module PAM lancé."
show_menu
echo "[IPSSEC] Fin du module PAM."
