#!/bin/bash
#===============================================================================
# Script      : scan-security.sh
# Description : Menu de sélection pour les scans de sécurité
#===============================================================================

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

afficher_aide() {
    clear
    cat << 'EOF'

===============================================================================
                         AIDE - OUTILS DE SÉCURITÉ
===============================================================================

  LYNIS
  -----
  Lynis est un outil d'audit de sécurité pour les systèmes Linux.
  Il analyse votre système et vérifie :
    - Les configurations de sécurité
    - Les permissions des fichiers
    - Les vulnérabilités connues
    - Les paramètres réseau et firewall
    - Les mises à jour disponibles

  RKHUNTER
  --------
  Rkhunter (Rootkit Hunter) détecte les menaces sur votre système :
    - Rootkits connus
    - Backdoors et exploits
    - Fichiers cachés suspects
    - Modifications de fichiers système
    - Processus malveillants

===============================================================================
EOF
    echo ""
    read -p "  Appuyez sur Entrée pour revenir au menu..."
}

afficher_stats() {
    clear
    echo ""
    echo -e "${YELLOW}===============================================================================${NC}"
    echo -e "${WHITE}                         STATISTIQUES DES RAPPORTS${NC}"
    echo -e "${YELLOW}===============================================================================${NC}"
    echo ""
    
    # Compte les rapports
    TOTAL_LYNIS=$(ls /var/log/security-reports/lynis_* 2>/dev/null | wc -l)
    TOTAL_RKHUNTER=$(ls /var/log/security-reports/rkhunter_* 2>/dev/null | wc -l)
    
    echo -e "  ${CYAN}Nombre de rapports :${NC}"
    echo -e "    - Lynis    : ${GREEN}$TOTAL_LYNIS${NC}"
    echo -e "    - Rkhunter : ${GREEN}$TOTAL_RKHUNTER${NC}"
    echo ""
    
    # Dernier rapport Lynis
    DERNIER_LYNIS=$(ls -t /var/log/security-reports/lynis_* 2>/dev/null | head -1)
    if [ -n "$DERNIER_LYNIS" ]; then
        echo -e "  ${CYAN}Dernier rapport Lynis :${NC}"
        WARNINGS_LYNIS=$(grep -ciE "warning" "$DERNIER_LYNIS" 2>/dev/null || echo "0")
        SUGGESTIONS_LYNIS=$(grep -ci "suggestion" "$DERNIER_LYNIS" 2>/dev/null || echo "0")
        echo -e "    - Warnings    : ${RED}$WARNINGS_LYNIS${NC}"
        echo -e "    - Suggestions : ${YELLOW}$SUGGESTIONS_LYNIS${NC}"
        echo ""
    fi
    
    # Dernier rapport Rkhunter
    DERNIER_RKHUNTER=$(ls -t /var/log/security-reports/rkhunter_* 2>/dev/null | head -1)
    if [ -n "$DERNIER_RKHUNTER" ]; then
        echo -e "  ${CYAN}Dernier rapport Rkhunter :${NC}"
        WARNINGS_RKH=$(grep -ciE "warning" "$DERNIER_RKHUNTER" 2>/dev/null || echo "0")
        SUSPECTS=$(grep -ciE "suspect|hidden" "$DERNIER_RKHUNTER" 2>/dev/null || echo "0")
        echo -e "    - Warnings         : ${RED}$WARNINGS_RKH${NC}"
        echo -e "    - Fichiers suspects: ${RED}$SUSPECTS${NC}"
        echo ""
    fi
    
    echo -e "${YELLOW}===============================================================================${NC}"
    echo ""
    read -p "  Appuyez sur Entrée pour revenir au menu..."
}

envoyer_mail() {
    clear
    echo ""
    echo -e "${YELLOW}===============================================================================${NC}"
    echo -e "${WHITE}                         ENVOYER UN RAPPORT PAR MAIL${NC}"
    echo -e "${YELLOW}===============================================================================${NC}"
    echo ""
    
    # Vérifie si mail est installé
    if ! command -v mail &> /dev/null; then
        echo -e "${RED}[ERREUR]${NC} mailutils n'est pas installé"
        echo ""
        echo -e "  Installez-le avec : ${CYAN}sudo apt install mailutils${NC}"
        echo ""
        read -p "  Appuyez sur Entrée pour revenir au menu..."
        return
    fi
    
    # Liste les rapports
    echo -e "  ${CYAN}Rapports disponibles :${NC}"
    echo ""
    ls /var/log/security-reports/
    echo ""
    
    # Demande le fichier
    read -p "  Nom du fichier à envoyer : " fichier
    
    if [ ! -f "/var/log/security-reports/$fichier" ]; then
        echo -e "${RED}[ERREUR]${NC} Fichier non trouvé"
        read -p "  Appuyez sur Entrée..."
        return
    fi
    
    # Demande l'adresse mail
    read -p "  Adresse email du destinataire : " email
    
    # Envoie le mail
    echo -e "${GREEN}[INFO]${NC} Envoi en cours..."
    mail -s "Rapport de sécurité IPSSEC - $fichier" "$email" < "/var/log/security-reports/$fichier"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[OK]${NC} Rapport envoyé à $email"
    else
        echo -e "${RED}[ERREUR]${NC} Échec de l'envoi"
    fi
    
    echo ""
    read -p "  Appuyez sur Entrée pour revenir au menu..."
}
convertir_pdf() {
    clear
    echo ""
    echo -e "${YELLOW}===============================================================================${NC}"
    echo -e "${WHITE}                         CONVERTIR UN RAPPORT EN PDF${NC}"
    echo -e "${YELLOW}===============================================================================${NC}"
    echo ""
    
    if ! command -v enscript &> /dev/null; then
        echo -e "${RED}[ERREUR]${NC} enscript n'est pas installe"
        echo ""
        echo -e "  Installez-le avec : ${CYAN}sudo apt install enscript ghostscript${NC}"
        echo ""
        read -p "  Appuyez sur Entree pour revenir au menu..."
        return
    fi
    
    echo -e "  ${CYAN}Rapports disponibles :${NC}"
    echo ""
    ls /var/log/security-reports/*.txt 2>/dev/null | xargs -n1 basename
    echo ""
    
    read -p "  Nom du fichier a convertir : " fichier
    
    if [ ! -f "/var/log/security-reports/$fichier" ]; then
        echo -e "${RED}[ERREUR]${NC} Fichier non trouve"
        read -p "  Appuyez sur Entree..."
        return
    fi
    
    PDF_NAME="${fichier%.txt}.pdf"
    
    echo -e "${GREEN}[INFO]${NC} Conversion en cours..."
    enscript -p /tmp/rapport.ps /var/log/security-reports/$fichier 2>/dev/null
    ps2pdf /tmp/rapport.ps /var/log/security-reports/$PDF_NAME
    rm /tmp/rapport.ps
    
    if [ -f "/var/log/security-reports/$PDF_NAME" ]; then
        echo -e "${GREEN}[OK]${NC} PDF cree : /var/log/security-reports/$PDF_NAME"
    else
        echo -e "${RED}[ERREUR]${NC} Echec de la conversion"
    fi
    
    echo ""
    read -p "  Appuyez sur Entree pour revenir au menu..."
}

afficher_menu() {
    clear
    echo ""
    echo -e "${CYAN}    ░██████░█████████    ░██████     ░██████   ░██████████   ░██████  ${NC}"
    echo -e "${CYAN}      ░██  ░██     ░██  ░██   ░██   ░██   ░██  ░██          ░██   ░██ ${NC}"
    echo -e "${CYAN}      ░██  ░██     ░██ ░██         ░██         ░██         ░██        ${NC}"
    echo -e "${CYAN}      ░██  ░█████████   ░████████   ░████████  ░█████████  ░██        ${NC}"
    echo -e "${CYAN}      ░██  ░██                 ░██         ░██ ░██         ░██        ${NC}"
    echo -e "${CYAN}      ░██  ░██          ░██   ░██   ░██   ░██  ░██          ░██   ░██ ${NC}"
    echo -e "${CYAN}    ░██████░██           ░██████     ░██████   ░██████████   ░██████  ${NC}"
    echo ""
    echo -e "${YELLOW}===============================================================================${NC}"
    echo -e "${WHITE}                    SCAN DE SÉCURITÉ - RKHUNTER & LYNIS${NC}"
    echo -e "${YELLOW}===============================================================================${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC}  Lancer un scan Lynis (audit système)"
    echo ""
    echo -e "  ${GREEN}[2]${NC}  Lancer un scan Rkhunter (détection rootkits)"
    echo ""
    echo -e "  ${GREEN}[3]${NC}  Lancer les deux scans"
    echo ""
    echo -e "  ${GREEN}[4]${NC}  Voir les rapports existants"
    echo ""
    echo -e "  ${GREEN}[5]${NC}  Aide - C'est quoi Lynis et Rkhunter ?"
    echo ""
    echo -e "  ${GREEN}[6]${NC}  Voir les statistiques"
    echo ""
    echo -e "  ${GREEN}[7]${NC}  Envoyer un rapport par mail"
    echo ""
    echo -e "  ${GREEN}[8]${NC}  Convertir un rapport en PDF"
    echo ""
    echo -e "  ${RED}[9]${NC}  Quitter"
    echo ""
    echo -e "${YELLOW}===============================================================================${NC}"
    echo ""
}

# Boucle principale
while true; do
    afficher_menu
    read -p "  Votre choix [1-8] : " choix

    case $choix in
        1)
            echo ""
            echo -e "${GREEN}[INFO]${NC} Lancement du scan Lynis..."
            echo ""
            scan-lynis
            echo ""
            read -p "  Appuyez sur Entrée pour revenir au menu..."
            ;;
        2)
            echo ""
            echo -e "${GREEN}[INFO]${NC} Lancement du scan Rkhunter..."
            echo ""
            scan-rkhunter
            echo ""
            read -p "  Appuyez sur Entrée pour revenir au menu..."
            ;;
        3)
            echo ""
            echo -e "${GREEN}[INFO]${NC} Lancement des deux scans..."
            echo ""
            scan-lynis
            scan-rkhunter
            echo ""
            read -p "  Appuyez sur Entrée pour revenir au menu..."
            ;;
        4)
            echo ""
            echo -e "${GREEN}[INFO]${NC} Rapports disponibles :"
            echo ""
            ls -lh /var/log/security-reports/
            echo ""
            read -p "  Appuyez sur Entrée pour revenir au menu..."
            ;;
        5)
            afficher_aide
            ;;
        6)
            afficher_stats
            ;;
        7)
            envoyer_mail
            ;;

	8)
            convertir_pdf
            ;;
        9)
            echo ""
            echo -e "${CYAN}Au revoir !${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo ""
            echo -e "${RED}[ERREUR]${NC} Choix invalide ! Veuillez entrer un chiffre entre 1 et 8."
            echo ""
            read -p "  Appuyez sur Entrée pour réessayer..."
            ;;
    esac
done
