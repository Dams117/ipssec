#!/bin/bash

# Couleurs pour le menu
GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
NC="\e[0m" # Pas de couleur

while true; do
    clear
    echo -e "${BLUE}==========================================${NC}"
    echo -e "${BLUE}         MENU SECURITE LINUX              ${NC}"
    echo -e "${BLUE}==========================================${NC}"
    echo -e "1) Vérifier les mises à jour du système"
    echo -e "2) Configurer le pare-feu (IPTables/Firewalld)"
    echo -e "3) Configurer IPSec (VPN, règles de sécurité)"
    echo -e "4) Sécuriser SSH (désactiver root, clés, ports)"
    echo -e "5) Auditer les utilisateurs et permissions"
    echo -e "6) Configurer l’audit et journaux (auditd, logwatch)"
    echo -e "7) Appliquer des politiques de hardening (CIS/Baselines)"
    echo -e "8) Quitter"
    echo -e "=========================================="
    
    read -p "Choisissez une option [1-8] : " choix

    case $choix in
        1)
            echo -e "${YELLOW}Mises à jour du système...${NC}"
            sudo apt update && sudo apt upgrade -y   # Debian/Ubuntu
            # sudo yum update -y  # CentOS/RHEL
            ;;
        2)
            echo -e "${YELLOW}Configuration du pare-feu...${NC}"
            sudo ufw enable
            sudo ufw default deny incoming
            sudo ufw default allow outgoing
            sudo ufw allow ssh
            sudo ufw status verbose
            ;;
        3)
            echo -e "${YELLOW}Configuration IPSec...${NC}"
            echo "Vérification/installation de strongSwan"
            sudo apt install -y strongswan  # Debian/Ubuntu
            sudo systemctl enable strongswan
            sudo systemctl start strongswan
            echo "Configuration de base terminée (ex. /etc/ipsec.conf)"
            ;;
        4)
            echo -e "${YELLOW}Sécurisation SSH...${NC}"
            sudo sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
            sudo sed -i 's/^#Port 22/Port 2222/' /etc/ssh/sshd_config
            sudo systemctl restart sshd
            echo "SSH sécurisé : root désactivé, port changé"
            ;;
        5)
            echo -e "${YELLOW}Audit des utilisateurs et permissions...${NC}"
            echo "Utilisateurs sudo :"
            getent group sudo
            echo "Comptes inactifs (90 jours) :"
            sudo chage -l $(whoami)
            ;;
        6)
            echo -e "${YELLOW}Configuration de l’audit et journaux...${NC}"
            sudo apt install -y auditd audispd-plugins
            sudo systemctl enable auditd
            sudo systemctl start auditd
            sudo ausearch -m USER_LOGIN
            ;;
        7)
            echo -e "${YELLOW}Application des politiques de hardening...${NC}"
            echo "Exemple : CIS Benchmark Linux (simplifié)"
            sudo chmod -R go-w /etc/ssh/
            sudo chown root:root /etc/passwd
            sudo chmod 600 /etc/shadow
            echo "Politiques de base appliquées"
            ;;
        8)
            echo -e "${GREEN}Au revoir !${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Option invalide. Veuillez choisir entre 1 et 8.${NC}"
            ;;
    esac
    echo
    read -p "Appuyez sur Entrée pour revenir au menu..."
done
