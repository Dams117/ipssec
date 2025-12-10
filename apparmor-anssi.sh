#!/bin/bash

# Script AppArmor ANSSI - Gestion interactive des profils AppArmor
# Détecte les services Ubuntu installés et applique les profils correspondants

BLANC='\033[1;37m'
VERT='\033[0;32m'
ROUGE='\033[0;31m'
CYAN='\033[0;36m'
JAUNE='\033[1;33m'
NORMAL='\033[0m'

# Chemins
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROFILES_DIR="${SCRIPT_DIR}/profiles/anssi"
TARGET_DIR="/etc/apparmor.d/anssi"
BACKUP_DIR="/etc/apparmor.d/anssi.backups"

# Mapping service systemd -> profil AppArmor
declare -A SERVICE_TO_PROFILE=(
    ["ssh.service"]="usr.sbin.sshd"
    ["sshd.service"]="usr.sbin.sshd"
    ["nginx.service"]="usr.sbin.nginx"
    ["apache2.service"]="usr.sbin.apache2"
    ["mysql.service"]="usr.sbin.mysqld"
    ["mariadb.service"]="usr.sbin.mysqld"
    ["postgresql.service"]="usr.sbin.postgresql"
    ["cups.service"]="usr.sbin.cupsd"
    ["cupsd.service"]="usr.sbin.cupsd"
    ["dhcpcd.service"]="usr.sbin.dhcpcd"
    ["NetworkManager.service"]="usr.sbin.NetworkManager"
    ["systemd-resolved.service"]="usr.sbin.systemd-resolved"
    ["systemd-networkd.service"]="usr.sbin.systemd-networkd"
    ["snapd.service"]="usr.sbin.snapd"
    ["avahi-daemon.service"]="usr.sbin.avahi-daemon"
    ["ufw.service"]="usr.sbin.ufw"
)

# Services détectés avec leurs profils
declare -a DETECTED_SERVICES=()
declare -a DETECTED_PROFILES=()

# ============================================================================
# FONCTIONS UTILITAIRES
# ============================================================================

show_banner() {
    clear
    cat << "EOF"

 ▄▄▄       ██▀███   ▄▄▄        ██████  ▄▄▄       ██ ▄█▀▄▄▄      
▒████▄    ▓██ ▒ ██▒▒████▄    ▒██    ▒ ▒████▄     ██▄█▒▒████▄    
▒██  ▀█▄  ▓██ ░▄█ ▒▒██  ▀█▄  ░ ▓██▄   ▒██  ▀█▄  ▓███▄░▒██  ▀█▄  
░██▄▄▄▄██ ▒██▀▀█▄  ░██▄▄▄▄██   ▒   ██▒░██▄▄▄▄██ ▓██ █▄░██▄▄▄▄██ 
 ▓█   ▓██▒░██▓ ▒██▒ ▓█   ▓██▒▒██████▒▒ ▓█   ▓██▒▒██▒ █▄▓█   ▓██▒
 ▒▒   ▓▒█░░ ▒▓ ░▒▓░ ▒▒   ▓▒█░▒ ▒▓▒ ▒ ░ ▒▒   ▓▒█░▒ ▒▒ ▓▒▒▒   ▓▒█░
  ▒   ▒▒ ░  ░▒ ░ ▒░  ▒   ▒▒ ░░ ░▒  ░ ░  ▒   ▒▒ ░░ ░▒ ▒░ ▒   ▒▒ ░
  ░   ▒     ░░   ░   ░   ▒   ░  ░  ░    ░   ▒   ░ ░░ ░  ░   ▒   
      ░  ░   ░           ░  ░      ░        ░  ░░  ░        ░  ░


EOF
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${ROUGE}[ERREUR] Ce script doit être exécuté en root.${NORMAL}"
        echo -e "${CYAN}Utilisez : sudo $0${NORMAL}"
        exit 1
    fi
}

# ============================================================================
# VÉRIFICATION ET INSTALLATION D'APPARMOR
# ============================================================================

is_apparmor_installed() {
    command -v apparmor_status >/dev/null 2>&1 || command -v aa-status >/dev/null 2>&1
}

install_apparmor_prompt() {
    echo -e "${ROUGE}AppArmor n'est pas installé sur ce système.${NORMAL}"
    echo -e "${CYAN}Souhaites-tu l'installer maintenant ?${NORMAL}"
    echo -e " ${VERT}1${NORMAL}) Oui, installer AppArmor"
    echo -e " ${ROUGE}0${NORMAL}) Non, quitter"
    read -rp "Choix : " choice

    case "$choice" in
        1) install_apparmor ;;
        0) echo -e "${ROUGE}Installation annulée. Au revoir.${NORMAL}"; exit 1 ;;
        *) install_apparmor_prompt ;;
    esac
}

install_apparmor() {
    echo -e "${CYAN}Détection de la distribution...${NORMAL}"

    if command -v apt >/dev/null 2>&1; then
        echo -e "${VERT}Installation AppArmor pour Debian/Ubuntu...${NORMAL}"
        apt update -y
        apt install -y apparmor apparmor-utils apparmor-profiles apparmor-profiles-extra
        systemctl enable apparmor --now
    elif command -v pacman >/dev/null 2>&1; then
        echo -e "${VERT}Installation AppArmor pour Arch Linux...${NORMAL}"
        pacman -Syu --noconfirm apparmor
        systemctl enable apparmor --now
        systemctl enable apparmor_parser --now
    elif command -v dnf >/dev/null 2>&1; then
        echo -e "${VERT}Installation AppArmor pour Fedora...${NORMAL}"
        dnf install -y apparmor apparmor-utils
        systemctl enable apparmor --now
    else
        echo -e "${ROUGE}Distribution non supportée automatiquement.${NORMAL}"
        exit 1
    fi

    echo -e "${VERT}AppArmor est maintenant installé.${NORMAL}"
    sleep 2
}

check_deps() {
    is_apparmor_installed || install_apparmor_prompt

    for cmd in aa-enforce aa-complain aa-status apparmor_parser; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo -e "${ROUGE}Commande introuvable : $cmd${NORMAL}"
            echo -e "${CYAN}Installation des dépendances manquantes...${NORMAL}"
            install_apparmor
            break
        fi
    done
}

# ============================================================================
# DÉTECTION DES SERVICES
# ============================================================================

detect_services() {
    echo -e "${CYAN}===== DÉTECTION DES SERVICES INSTALLÉS =====${NORMAL}"
    echo
    
    DETECTED_SERVICES=()
    DETECTED_PROFILES=()
    
    # Récupérer la liste des services installés (actifs ou non)
    local services_list
    services_list=$(systemctl list-unit-files --type=service --no-pager --no-legend 2>/dev/null | awk '{print $1}' || true)
    
    if [[ -z "$services_list" ]]; then
        echo -e "${ROUGE}Impossible de détecter les services systemd.${NORMAL}"
        return 1
    fi
    
    local count=0
    while IFS= read -r service; do
        [[ -z "$service" ]] && continue
        
        # Vérifier si le service a un profil correspondant dans notre mapping
        local profile="${SERVICE_TO_PROFILE[$service]}"
        if [[ -n "$profile" ]]; then
            # Vérifier si le profil existe physiquement dans notre dossier local
            local profile_file="${PROFILES_DIR}/${profile}"
            if [[ -f "$profile_file" ]]; then
                DETECTED_SERVICES+=("$service")
                DETECTED_PROFILES+=("$profile")
                ((count++))
            fi
        fi
    done <<< "$services_list"
    
    if [[ $count -eq 0 ]]; then
        echo -e "${JAUNE}Aucun service avec profil disponible n'a été détecté.${NORMAL}"
        echo -e "${CYAN}Assurez-vous que les profils sont présents dans : ${PROFILES_DIR}${NORMAL}"
        return 1
    fi
    
    echo -e "${VERT}${count} service(s) détecté(s) avec profil(s) disponible(s) :${NORMAL}"
    echo
    
    for i in "${!DETECTED_SERVICES[@]}"; do
        local service="${DETECTED_SERVICES[$i]}"
        local profile="${DETECTED_PROFILES[$i]}"
        local status
        status=$(systemctl is-active "$service" 2>/dev/null || echo "inactif")
        
        local status_color="${ROUGE}"
        [[ "$status" == "active" ]] && status_color="${VERT}"
        
        printf "  ${CYAN}%2d${NORMAL}) ${BLANC}%-30s${NORMAL} → ${VERT}%s${NORMAL} [${status_color}%s${NORMAL}]\n" \
            $((i+1)) "$service" "$profile" "$status"
    done
    
    echo
    return 0
}

# ============================================================================
# GESTION DES BACKUPS
# ============================================================================

backup_existing_profile() {
    local profile="$1"
    local target_file="${TARGET_DIR}/${profile}"
    
    [[ ! -f "$target_file" ]] && return 0  # Pas de backup nécessaire
    
    mkdir -p "$BACKUP_DIR"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/${profile}.backup_${timestamp}"
    
    cp "$target_file" "$backup_file"
    echo -e "${CYAN}  → Backup créé : ${backup_file}${NORMAL}"
}

# ============================================================================
# COPIE ET APPLICATION DES PROFILS
# ============================================================================

explain_modes() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NORMAL}"
    echo -e "${JAUNE}MODES DE PROTECTION APPARMOR :${NORMAL}"
    echo
    echo -e "  ${VERT}ENFORCE (Strict)${NORMAL}"
    echo -e "  Bloque toutes les actions non autorisées par le profil."
    echo -e "  Idéal pour la production, mais peut bloquer le service s'il manque des règles."
    echo
    echo -e "  ${CYAN}COMPLAIN (Apprentissage)${NORMAL}"
    echo -e "  Autorise tout mais loggue les violations dans les journaux système."
    echo -e "  Permet de tester un profil sans risquer de casser le service."
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NORMAL}"
    echo
}

apply_profile() {
    local index="$1"
    local service="${DETECTED_SERVICES[$index]}"
    local profile="${DETECTED_PROFILES[$index]}"
    local source_file="${PROFILES_DIR}/${profile}"
    local target_file="${TARGET_DIR}/${profile}"
    
    echo -e "${CYAN}Traitement du service : ${VERT}$service${NORMAL} (Profil : $profile)"
    
    # Choix du mode
    explain_modes
    echo -e "Quel mode souhaitez-vous appliquer ?"
    echo -e "  ${VERT}1${NORMAL}) Enforce"
    echo -e "  ${CYAN}2${NORMAL}) Complain"
    echo -e "  ${ROUGE}0${NORMAL}) Annuler"
    read -rp "Choix : " mode_choice
    
    local mode=""
    case "$mode_choice" in
        1) mode="enforce" ;;
        2) mode="complain" ;;
        0) echo -e "${ROUGE}Annulé.${NORMAL}"; return ;;
        *) echo -e "${ROUGE}Choix invalide.${NORMAL}"; return ;;
    esac

    # Créer le dossier cible s'il n'existe pas
    mkdir -p "$TARGET_DIR"
    
    # Sauvegarder le profil existant s'il y en a un
    backup_existing_profile "$profile"
    
    # Copier le profil
    echo -e "${CYAN}Copie du profil...${NORMAL}"
    if cp "$source_file" "$target_file"; then
        echo -e "${VERT}  ✓ Fichier copié.${NORMAL}"
    else
        echo -e "${ROUGE}  ✗ Erreur de copie.${NORMAL}"
        return 1
    fi
    
    # Vérifier la syntaxe et charger
    echo -e "${CYAN}Chargement du profil...${NORMAL}"
    if apparmor_parser -r "$target_file"; then
        echo -e "${VERT}  ✓ Profil chargé avec succès.${NORMAL}"
    else
        echo -e "${ROUGE}  ✗ Erreur lors du chargement (syntaxe invalide ?).${NORMAL}"
        return 1
    fi
    
    # Appliquer le mode
    echo -e "${CYAN}Application du mode ${mode^^}...${NORMAL}"
    if [[ "$mode" == "enforce" ]]; then
        aa-enforce "$target_file"
    else
        aa-complain "$target_file"
    fi
    
    echo -e "${VERT}Terminé pour $service.${NORMAL}"
    sleep 2
}

# ============================================================================
# MENU PRINCIPAL
# ============================================================================

main_menu() {
    while true; do
        show_banner
        
        # Rafraîchir la détection à chaque affichage du menu
        detect_services
        local service_count=${#DETECTED_SERVICES[@]}
        
        if [[ $service_count -eq 0 ]]; then
            echo -e "${JAUNE}Aucun service détecté. Vérifiez le dossier profiles/anssi/.${NORMAL}"
            echo -e "${ROUGE}0${NORMAL}) Quitter"
            read -rp "Choix : " choice
            [[ "$choice" == "0" ]] && exit 0
            continue
        fi
        
        echo -e "Entrez le ${VERT}numéro${NORMAL} du service à protéger, ou :"
        echo -e "  ${VERT}a${NORMAL}) Tout appliquer en mode COMPLAIN (Audit)"
        echo -e "  ${VERT}s${NORMAL}) Afficher le statut global (aa-status)"
        echo -e "  ${ROUGE}0${NORMAL}) Quitter"
        echo
        read -rp "Votre choix : " choice
        
        case "$choice" in
            0) 
                echo -e "${ROUGE}Au revoir !${NORMAL}"
                exit 0 
                ;;
            s|S)
                aa-status
                read -rp "Appuyez sur Entrée..."
                ;;
            a|A)
                for i in "${!DETECTED_SERVICES[@]}"; do
                    # Simuler le choix complain pour tous
                    # Note: Pour simplifier, on pourrait faire une fonction dédiée "apply_all_complain"
                    # Ici on va juste appeler aa-complain sur les fichiers copiés
                    local p="${DETECTED_PROFILES[$i]}"
                    local sf="${PROFILES_DIR}/${p}"
                    local tf="${TARGET_DIR}/${p}"
                    mkdir -p "$TARGET_DIR"
                    cp "$sf" "$tf"
                    apparmor_parser -r "$tf"
                    aa-complain "$tf"
                    echo -e "${VERT}Appliqué $p en Complain${NORMAL}"
                done
                read -rp "Terminé. Appuyez sur Entrée..."
                ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= service_count)); then
                    apply_profile $((choice-1))
                else
                    echo -e "${ROUGE}Choix invalide.${NORMAL}"
                    sleep 1
                fi
                ;;
        esac
    done
}

# ============================================================================
# EXÉCUTION
# ============================================================================

require_root
check_deps
main_menu
