#!/bin/bash

# Couleurs pour le menu
GREEN="\e[32m"
RED="\e[31m"
BLUE="\e[34m"
NC="\e[0m" # Pas de couleur

while true; do
    clear
    echo -e "${BLUE}==============================${NC}"
    echo -e "${BLUE}       MENU PRINCIPAL         ${NC}"
    echo -e "${BLUE}==============================${NC}"
    echo -e "Mises à jour"
    echo -e "Pare-feu"
    echo -e "IPSec"
    echo -e "SSH"
    echo -e "Audit"
    echo -e "Hardening"
    echo -e "Quitter"
    echo -e "==============================" 

    read -p "Choisissez une option : " choix

    case "${choix,,}" in
        "mises à jour"|"mise à jour"|"update")
            echo -e "${GREEN}Vous avez choisi Mises à jour${NC}"
            ;;
        "pare-feu"|"firewall")
            echo -e "${GREEN}Vous avez choisi Pare-feu${NC}"
            ;;
        "ipsec")
            echo -e "${GREEN}Vous avez choisi IPSec${NC}"
            ;;
        "ssh")
            echo -e "${GREEN}Vous avez choisi SSH${NC}"
            ;;
        "audit")
            echo -e "${GREEN}Vous avez choisi Audit${NC}"
            ;;
        "hardening")
            echo -e "${GREEN}Vous avez choisi Hardening${NC}"
            ;;
        "quitter"|"exit")
            echo -e "${GREEN}Au revoir !${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Option invalide${NC}"
            ;;
    esac
    echo
    read -p "Appuyez sur Entrée pour revenir au menu..."
done
