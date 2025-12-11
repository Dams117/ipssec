#!/bin/bash
 
# =========================================================================
# Pare-feu v4.1 - Gestion des règles iptables (IPv4) avec Persistance et Mode Interactif
# =========================================================================
 
# Fichier de Sauvegarde des Règles (Pour la persistance)
RULES_FILE="/etc/iptables/brainfw_rules.v4"
WORKPLACE="/root/tmp"
ACTION="$1"
BLOCKFORMAT="$2"
TARGET="$3"
 
# --- Regex pour la validation IP/CIDR ---
IP_REGEX="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
CIDR_REGEX="^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\/(([0-9]|[1-2][0-9]|3[0-2]))$"
 
 
# --- Fonctions utilitaires de base ---
 
function check_workplace() {
    WORKPLACE="$1"
 
    if [[ ! -e "$WORKPLACE" ]]
    then
        echo "$WORKPLACE n'existe pas, création..."
        mkdir -p "$WORKPLACE"
    else
        if [[ ! -d "$WORKPLACE" ]]
        then
            echo "Alerte: $WORKPLACE est un fichier, arrêt..."
            exit 1
        else
            echo "$WORKPLACE est un répertoire, traitement..."
        fi
    fi
    # Assurer que le répertoire de sauvegarde existe
    mkdir -p "$(dirname "$RULES_FILE")"
}
 
function get_country() {
    WORKPLACE="$1"
    COUNTRY="$2"
   
    # URL de base des blocs IP agrégés
    BASE_URL="http://www.ipdeny.com/ipblocks/data/aggregated"
 
    if [[ "$COUNTRY" == "WORLD" ]]; then
        # Cible spéciale pour l'ensemble des IP routables du monde
        FILENAME="world-aggregated.zone"
    else
        # Fichier spécifique à un pays
        FILENAME="$COUNTRY-aggregated.zone"
    fi
 
    # Le nom du fichier local est toujours $COUNTRY.zone
    FILEPATH="$WORKPLACE/$COUNTRY.zone"
 
    echo "Tentative de téléchargement des blocs IP pour $COUNTRY depuis $BASE_URL/$FILENAME..."
   
    # Tente de télécharger le fichier
    wget -q "$BASE_URL/$FILENAME" -O "$FILEPATH"
   
    if [[ $? -ne 0 ]]; then
        echo "ERREUR: Impossible de télécharger la liste IP pour le code $COUNTRY. Vérifiez le code ou la connexion."
        return 1
    fi
   
    # Vérifie si le fichier téléchargé contient des données
    if [[ ! -s "$FILEPATH" ]]; then
        echo "ERREUR: Le fichier téléchargé est vide. La cible ($COUNTRY) est probablement invalide ou inexistante."
        rm -f "$FILEPATH" # Suppression du fichier vide
        return 1
    fi
   
    return 0
}
 
function blockip() {
    IP="$1"
    # Utilise -I INPUT pour que les règles de blocage spécifiques soient prioritaires (devant les ports ouverts)
    iptables -I INPUT -s "$IP" -j DROP -v
}
 
function unblockip() {
    IP="$1"
    # Supprime la règle existante
    iptables -D INPUT -s "$IP" -j DROP -v
}
 
# --- Fonction de Sauvegarde des Règles ---
 
function save_user_rules() {
    echo "Sauvegarde des règles actuelles dans $RULES_FILE..."
    iptables-save > "$RULES_FILE"
    if [[ $? -eq 0 ]]; then
        echo "Sauvegarde réussie."
    else
        echo "ERREUR: Échec de la sauvegarde d'iptables."
    fi
}
 
# --- Fonctions de Gestion de Port (Activation/Désactivation) ---
 
function manageport() {
    ACTION="$1" # 'open' ou 'close'
    PORT="$2"
    PROTOCOL="$3" # 'tcp' ou 'udp'
 
    LOCAL_RULE="-p $PROTOCOL --dport $PORT -j ACCEPT"
 
    if [[ "$PORT" = "22" && "$PROTOCOL" = "tcp" ]]; then
        SSH_LIMIT_RULE="-p tcp --dport 22 -m conntrack --ctstate NEW -m limit --limit 6/minute --limit-burst 1 -j ACCEPT"
        SSH_ACCEPT_RULE="-p tcp --dport 22 -j ACCEPT"
 
        if [[ "$ACTION" = "open" ]]; then
            if iptables -C USER_PORTS $SSH_ACCEPT_RULE 2>/dev/null; then
                echo "Avertissement: Le port SSH est déjà ouvert et protégé."
            else
                # Ajout de la règle de limite puis de la règle d'acceptation dans USER_PORTS
                iptables -A USER_PORTS $SSH_LIMIT_RULE -v
                iptables -A USER_PORTS $SSH_ACCEPT_RULE -v
                echo "Succès: Port 22/tcp (SSH) ouvert avec protection Anti-Brute Force."
                save_user_rules # Sauvegarde après modification
            fi
        elif [[ "$ACTION" = "close" ]]; then
            if iptables -C USER_PORTS $SSH_ACCEPT_RULE 2>/dev/null; then
                # Suppression des règles
                iptables -D USER_PORTS $SSH_ACCEPT_RULE -v 2>/dev/null
                iptables -D USER_PORTS $SSH_LIMIT_RULE -v 2>/dev/null
                echo "Succès: Port 22/tcp (SSH) fermé et protection retirée."
                save_user_rules # Sauvegarde après modification
            else
                echo "Avertissement: La règle SSH n'a pas été trouvée pour être fermée."
            fi
        fi
        return
    fi
 
    if [[ "$ACTION" = "open" ]]; then
        if iptables -C USER_PORTS $LOCAL_RULE 2>/dev/null; then
            echo "Avertissement: Le port $PORT/$PROTOCOL est déjà ouvert."
        else
            iptables -A USER_PORTS $LOCAL_RULE -v
            echo "Succès: Port $PORT/$PROTOCOL ouvert."
            save_user_rules # Sauvegarde après modification
        fi
 
    elif [[ "$ACTION" = "close" ]]; then
        if iptables -C USER_PORTS $LOCAL_RULE 2>/dev/null; then
            iptables -D USER_PORTS $LOCAL_RULE -v
            echo "Succès: Port $PORT/$PROTOCOL fermé."
            save_user_rules # Sauvegarde après modification
        else
            echo "Avertissement: La règle pour le port $PORT/$PROTOCOL n'a pas été trouvée pour être fermée."
        fi
    fi
}
 
function port_management_mode() {
    # Assure que les règles de base sont appliquées et que la chaîne USER_PORTS existe
    setup_ipv4_base_rules
   
    while true; do
        echo "=============================================="
        echo "Mode 1 : Gestion des Ports (Ouverture/Fermeture)"
        echo "=============================================="
        echo "1. Afficher les règles de ports ouverts (Chaîne USER_PORTS)"
        echo "2. Ouvrir un port (TCP/UDP) - Protège SSH si 22/tcp"
        echo "3. Fermer un port (TCP/UDP)"
        echo "4. Retour au Menu Principal"
        echo "----------------------------------------------"
 
        read -p "Votre choix [1-4] : " CHOICE
 
        case "$CHOICE" in
            1)
                echo "--- Règles d'Ouverture de Ports (Chaîne USER_PORTS) ---"
                # On filtre l'affichage pour ne montrer que la chaîne USER_PORTS
                iptables -nL USER_PORTS --line-numbers 2>/dev/null || echo "La chaîne USER_PORTS n'existe pas ou est vide."
                ;;
            2)
                read -p "Port à ouvrir (1-65535) : " PORT
                if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [[ "$PORT" -le 0 ]] || [[ "$PORT" -gt 65535 ]]; then
                    echo "ERREUR: Port invalide."
                    continue
                fi
                read -p "Protocole (tcp/udp) : " PROTOCOL
                PROTOCOL=$(echo "$PROTOCOL" | tr '[:upper:]' '[:lower:]')
                if [[ "$PROTOCOL" != "tcp" && "$PROTOCOL" != "udp" ]]; then
                    echo "ERREUR: Protocole invalide. Utiliser 'tcp' ou 'udp'."
                    continue
                fi
                manageport "open" "$PORT" "$PROTOCOL"
                ;;
            3)
                read -p "Port à fermer (1-65535) : " PORT
                if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [[ "$PORT" -le 0 ]] || [[ "$PORT" -gt 65535 ]]; then
                    echo "ERREUR: Port invalide."
                    continue
                fi
                read -p "Protocole (tcp/udp) : " PROTOCOL
                PROTOCOL=$(echo "$PROTOCOL" | tr '[:upper:]' '[:lower:]')
                if [[ "$PROTOCOL" != "tcp" && "$PROTOCOL" != "udp" ]]; then
                    echo "ERREUR: Protocole invalide. Utiliser 'tcp' ou 'udp'."
                    continue
                fi
                manageport "close" "$PORT" "$PROTOCOL"
                ;;
            4)
                echo "Retour au Menu Principal..."
                return # Retourne à main_menu
                ;;
            *)
                echo "Choix invalide. Veuillez saisir un nombre entre 1 et 4."
                ;;
        esac
    done
}
 
 
# --- Règles de Base Automatisées (IPv4 UNIQUEMENT) ---
 
function setup_ipv4_base_rules() {
    echo "--- Initialisation et Nettoyage du Firewall IPv4 (iptables) ---"
   
    # 1. NETTOYAGE OBLIGATOIRE (VIDER TOUT)
    iptables -F     # Vider toutes les règles
    iptables -X     # Supprimer les chaînes personnalisées (si elles existent)
   
    # 2. RÈGLES DE BASE SÉCURITAIRES
    # Politique par défaut: Tout ce qui ne correspond à aucune règle est DROPPÉ
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    echo "Politiques par défaut IPv4 : INPUT/FORWARD = DROP."
   
    # 3. CRÉATION des chaînes essentielles pour la RESTAURATION
    iptables -N USER_PORTS 2>/dev/null
 
    # 4. RESTAURATION des règles précédemment sauvegardées
    if [[ -f "$RULES_FILE" ]]; then
        echo "Restauration des règles utilisateur (y compris blocages IP/Pays persistants) depuis $RULES_FILE..."
        iptables-restore < "$RULES_FILE" 2>/dev/null
        echo "Règles restaurées. Réapplication des règles de base fixes..."
    else
        echo "Aucun fichier de règles utilisateur ($RULES_FILE) trouvé. Démarrage vierge."
    fi
 
    #
 
    # 5. RÈGLES FIXES (Appliquées à chaque lancement, après la restauration)
    # Elles doivent être ré-appliquées APRÈS la restauration pour garantir leur existence/ordre.
 
    # Règle de STABILITÉ (Loopback et Conntrack)
    iptables -I INPUT 1 -i lo -j ACCEPT                                 # Index 1 (haute priorité)
    iptables -I INPUT 2 -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT    # Index 2
    iptables -I INPUT 3 -m conntrack --ctstate INVALID -j DROP          # Index 3
 
    # PROTECTION CONTRE LE SCANNING DE PORTS (Anti-port scan)
    echo "Ajout/Vérification de la protection contre le scanning de ports..."
    if ! iptables -C INPUT -p tcp -m recent --update --seconds 60 --hitcount 20 --name PORT_SCAN -j DROP 2>/dev/null; then
        iptables -A INPUT -p tcp -m recent --update --seconds 60 --hitcount 20 --name PORT_SCAN -j DROP
    fi
    if ! iptables -C INPUT -p tcp -m recent --set --name PORT_SCAN 2>/dev/null; then
        iptables -A INPUT -p tcp -m recent --set --name PORT_SCAN
    fi
   
    # PROTECTION ANTI-DDOS/SYN FLOOD (Limiter les nouvelles connexions TCP)
    echo "Ajout/Vérification de la protection anti-DDoS (limitation de débit)..."
    if ! iptables -C INPUT -p tcp -m conntrack --ctstate NEW -m limit --limit 60/minute --limit-burst 20 -j ACCEPT 2>/dev/null; then
        iptables -A INPUT -p tcp -m conntrack --ctstate NEW -m limit --limit 60/minute --limit-burst 20 -j ACCEPT
    fi
   
    # CHAÎNE DE PORTS UTILISATEUR (Point de saut vers USER_PORTS)
    if ! iptables -C INPUT -j USER_PORTS 2>/dev/null; then
        iptables -A INPUT -j USER_PORTS
        echo "Ajout de la règle de saut vers la chaîne USER_PORTS."
    fi
 
    # DIAGNOSTIC ET LOGGING
    if ! iptables -C INPUT -p icmp -j ACCEPT 2>/dev/null; then
        iptables -A INPUT -p icmp -j ACCEPT # Autoriser le ping
    fi
    if ! iptables -C INPUT -m limit --limit 1/s --limit-burst 10 -j LOG --log-prefix "FW_BLOCKED_INPUT: " 2>/dev/null; then
        iptables -A INPUT -m limit --limit 1/s --limit-burst 10 -j LOG --log-prefix "FW_BLOCKED_INPUT: "
    fi
 
    echo "Règles IPv4 de base et sécuritaires appliquées."
}
 
# --- Logique Principale : Fonction CORE (Blocage/Déblocage IP/Pays) ---
 
function core() {
    ACTION="$1"
    BLOCKFORMAT="$2"
    TARGET="$3"
    WORKPLACE="$4"
   
    if [[ "$BLOCKFORMAT" = "country" ]]
    then
        get_country "$WORKPLACE" "$TARGET"
       
        # Vérification après le téléchargement
        FILE_TO_READ="$WORKPLACE/$TARGET.zone"
       
        if [[ ! -f "$FILE_TO_READ" ]]; then
            echo "Traitement annulé suite à l'échec du téléchargement du fichier zone."
            exit 1
        fi
 
        HOWMANYLINES=$(cat "$FILE_TO_READ" | wc -l)
 
        if [[ "$ACTION" = "block" ]]
        then
            echo "ATTENTION: Le traitement de $TARGET ($HOWMANYLINES lignes) peut prendre du temps. NE PAS INTERROMPRE."
            echo "Démarrage du traitement de la liste noire..."
           
            # Lecture ligne par ligne pour plus de robustesse que `for LINE in $(cat ...)`
            while read LINE; do
                blockip "$LINE" 2>/dev/null
            done < "$FILE_TO_READ"
           
            save_user_rules
            echo "Terminé ! Cible $TARGET ($HOWMANYLINES blocs) traitée et règles sauvegardées."
 
        elif [[ "$ACTION" = "unblock" ]]
        then
            echo "ATTENTION: Le traitement de $TARGET ($HOWMANYLINES lignes) peut prendre du temps. NE PAS INTERROMPRE."
            echo "Démarrage du traitement du déblocage..."
           
            while read LINE; do
                unblockip "$LINE" 2>/dev/null
            done < "$FILE_TO_READ"
           
            save_user_rules
            echo "Terminé ! Cible $TARGET ($HOWMANYLINES blocs) traitée et règles sauvegardées."
       
        else
            echo "$ACTION invalide, arrêt..."
            exit 1
        fi
       
    elif [[ "$BLOCKFORMAT" = "ip" ]]
    then
       
        # Utilisation des variables REGEX pré-définies
        if [[ "$TARGET" =~ $IP_REGEX || "$TARGET" =~ $CIDR_REGEX ]]
        then
            echo "Format IP/CIDR $TARGET est valide."
 
            if [[ "$TARGET" != "0.0.0.0" && "$TARGET" != "0.0.0.0/0" ]]
            then
                if [[ "$ACTION" = "block" ]]
                then
                    echo "Traitement de la liste noire pour $TARGET..."
                    blockip "$TARGET" 2>/dev/null
                    save_user_rules
                    echo "Terminé ! $TARGET bloqué et règles sauvegardées."
                elif [[ "$ACTION" = "unblock" ]]
                then
                    echo "Traitement du déblocage pour $TARGET..."
                    if unblockip "$TARGET" 2>/dev/null; then
                        save_user_rules
                        echo "Terminé ! $TARGET débloqué et règles sauvegardées."
                    else
                        echo "Avertissement : La règle pour $TARGET n'a peut-être pas été trouvée pour être supprimée."
                    fi
                else
                    echo "$ACTION invalide, processus annulé..."
                    exit 1
                fi
            else
                echo "ATTENTION: Vous ne pouvez pas bloquer ou débloquer 0.0.0.0 (toutes les adresses)."
                exit 1
            fi
        else
            echo "ERREUR: $TARGET est une adresse IP ou un format CIDR invalide. Processus annulé."
            exit 1
        fi
 
    else
        echo "Format de blocage : $BLOCKFORMAT invalide, arrêt."
        exit 1
    fi
}
 
# --- Fonction de Mode Interactif (Blocage/Déblocage IP/Pays) ---
 
function interactive_mode() {
    setup_ipv4_base_rules
    echo "=================================================="
    echo "Mode 2 : Blocage/Déblocage (IP, CIDR, Pays/WORLD)"
    echo "=================================================="
   
    # 1. Choisir l'action
    ACTION_CHOICE=""
    echo "--- Choix de l'action ---"
    while [[ "$ACTION_CHOICE" != "b" && "$ACTION_CHOICE" != "u" ]]; do
        read -p "Voulez-vous **B**loquer ou **U**nbloquer ? [B/U] : " ACTION_CHOICE
        ACTION_CHOICE=$(echo "$ACTION_CHOICE" | head -c 1 | tr '[:upper:]' '[:lower:]')
    done
    ACTION=$([[ "$ACTION_CHOICE" = "b" ]] && echo "block" || echo "unblock")
   
    # 2. Choisir le format
    BLOCKFORMAT_CHOICE=""
    echo "--- Choix du format ---"
    while [[ "$BLOCKFORMAT_CHOICE" != "i" && "$BLOCKFORMAT_CHOICE" != "c" ]]; do
        read -p "Agir sur une **I**P/CIDR ou un **C**ountry/WORLD ? [I/C] : " BLOCKFORMAT_CHOICE
        BLOCKFORMAT_CHOICE=$(echo "$BLOCKFORMAT_CHOICE" | head -c 1 | tr '[:upper:]' '[:lower:]')
    done
    BLOCKFORMAT=$([[ "$BLOCKFORMAT_CHOICE" = "i" ]] && echo "ip" || echo "country")
 
    # 3. Choisir et VALIDER la cible
    TARGET_PROMPT=""
    TARGET_INPUT=""
    VALID_TARGET=0
 
    echo "--- Saisie de la cible ---"
    while [[ $VALID_TARGET -eq 0 ]]; do
        if [[ "$BLOCKFORMAT" = "ip" ]]; then
            TARGET_PROMPT="Entrez l'adresse IP simple (ex: 1.1.1.1) ou le CIDR (ex: 1.1.1.0/24) : "
            read -p "$TARGET_PROMPT" TARGET_INPUT
            TARGET_INPUT=$(echo "$TARGET_INPUT" | tr -d ' ')
 
            if [[ "$TARGET_INPUT" =~ $IP_REGEX || "$TARGET_INPUT" =~ $CIDR_REGEX ]]
            then
                if [[ "$TARGET_INPUT" != "0.0.0.0" && "$TARGET_INPUT" != "0.0.0.0/0" ]]; then
                    VALID_TARGET=1
                else
                    echo "ATTENTION: Vous ne pouvez pas cibler 0.0.0.0/0 ou 0.0.0.0."
                fi
            else
                echo "ERREUR: Format IP/CIDR invalide. Veuillez réessayer."
            fi
 
        else # country/WORLD
            TARGET_PROMPT="Entrez le code pays (ex: FR, DE) ou **WORLD** pour tout le trafic public : "
            read -p "$TARGET_PROMPT" TARGET_INPUT
            TARGET_INPUT=$(echo "$TARGET_INPUT" | tr -d ' ' | tr '[:lower:]' '[:upper:]')
           
            if [[ "$TARGET_INPUT" =~ ^[A-Z]{2}$ || "$TARGET_INPUT" = "WORLD" ]]; then
                    VALID_TARGET=1
            else
                    echo "ERREUR: Le code doit être un code pays de deux lettres ou 'WORLD'. Veuillez réessayer."
            fi
        fi
    done
    TARGET="$TARGET_INPUT"
 
    echo "--- Récapitulatif ---"
    echo "Action : **$ACTION**"
    echo "Format : **$BLOCKFORMAT**"
    echo "Cible : **$TARGET**"
    echo "---------------------"
 
    read -p "Êtes-vous sûr de vouloir continuer avec ces paramètres ? [oui/non] : " CONFIRM
    CONFIRM=$(echo "$CONFIRM" | tr '[:upper:]' '[:lower:]')
   
    if [[ "$CONFIRM" = "oui" ]]; then
        echo "Démarrage du processus. Soyez patient pour $TARGET..."
        core "$ACTION" "$BLOCKFORMAT" "$TARGET" "$WORKPLACE"
    else
        echo "Opération annulée par l'utilisateur."
    fi
   
    return
}
 
# --- Fonction de Menu Principal (Point d'entrée) ---
 
function main_menu() {
    setup_ipv4_base_rules
   
    while true; do
        echo "=============================================="
        echo "Pare-feu - Menu Principal"
        echo "=============================================="
        echo "1. Gestion des Ports (Ouverture/Fermeture)"
        echo "2. Blocage/Déblocage (IP, CIDR, Pays/WORLD)"
        echo "3. Afficher l'état du Pare-feu (iptables -nL)"
        echo "4. Réinitialiser le Pare-feu aux règles de base"
        echo "5. Quitter"
        echo "----------------------------------------------"
 
        read -p "Votre choix [1-5] : " CHOICE
 
        case "$CHOICE" in
            1)
                port_management_mode
                ;;
            2)
                interactive_mode
                ;;
            3)
                ./brainfw.sh show
                ;;
            4)
                ./brainfw.sh reset
                ;;
            5)
                echo "Sauvegarde finale des règles avant de quitter..."
                save_user_rules
                echo "Arrêt du Pare-feu. Au revoir !"
                exit 0
                ;;
            *)
                echo "Choix invalide. Veuillez saisir un nombre entre 1 et 5."
                ;;
        esac
    done
}
 
 
# --- Logique d'entrée : Fonction ACTION (Appel final) ---
 
function action() {
    ACTION="$1"
    BLOCKFORMAT="$2"
    TARGET="$3"
    WORKPLACE="$4"
   
    check_workplace "$WORKPLACE"
 
    if [[ "$ACTION" = "show" ]]
    then
        echo "========================================================================="
        echo "Affichage des règles iptables actuelles :"
        echo "========================================================================="
        iptables -nL
        echo "========================================================================="
        exit 0
 
    elif [[ "$ACTION" = "reset" ]]
    then
        echo "========================================================================="
        echo "Réinitialisation du pare-feu aux règles de base sécuritaires..."
        echo "========================================================================="
        setup_ipv4_base_rules
        echo "Suppression du fichier de sauvegarde ($RULES_FILE)..."
        rm -f "$RULES_FILE" 2>/dev/null
        echo "Réinitialisation terminée. Vérifiez avec ./brainfw.sh show."
        exit 0
   
    elif [[ "$ACTION" = "manageports" ]]
    then
        port_management_mode
        exit 0
       
    elif [[ "$ACTION" = "interactive" ]] || [[ -z "$ACTION" ]]
    then
        main_menu
        exit 0
   
    elif [[ "$ACTION" = "block" || "$ACTION" = "unblock" ]]
    then
        setup_ipv4_base_rules
        if [[ -z "$BLOCKFORMAT" ]] || [[ -z "$TARGET" ]]; then
            echo "ERREUR: Les arguments {blockformat} et {target} sont requis pour l'action '$ACTION'."
            echo "Utilisez './brainfw.sh help' pour l'aide."
            exit 1
        fi
        core "$ACTION" "$BLOCKFORMAT" "$TARGET" "$WORKPLACE"
       
    elif [[ "$ACTION" = "help" ]]
    then
        echo "========================================================================="
        echo "Pare-feu - Aide et Syntaxe"
        echo "========================================================================="
        echo "Mode Guidé : Lancez le script sans argument ou avec 'interactive' pour le Menu Principal."
        echo "             -> $0"
        echo "-------------------------------------------------------------------------"
        echo "Actions Simples (Mode Ligne de Commande) : $0 {ACTION} {FORMAT} {CIBLE}"
        echo "-------------------------------------------------------------------------"
        echo "Exemples : $0 block country CN"
        echo "         : $0 unblock ip 192.168.1.100"
        echo "         : $0 block country WORLD"
        echo "========================================================================="
       
    else
        echo "Action '$ACTION' invalide. Utilisez 'help' pour l'aide."
        exit 1
    fi
}
 
# --- Démarrage du script (L'appel final) ---
 
action "$ACTION" "$BLOCKFORMAT" "$TARGET" "$WORKPLACE"
