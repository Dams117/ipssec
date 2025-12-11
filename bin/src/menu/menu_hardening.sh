#!/bin/bash

echo "Menu Hardening Linux"
echo "1) Mettre à jour le système"
echo "2) Configurer le pare-feu"
echo "3) Quitter"

read -p "Choisissez une option : " choix

case $choix in
  1) sudo apt update && sudo apt upgrade -y ;;
  2) sudo ufw enable && sudo ufw default deny incoming ;;
  3) exit 0 ;;
  *) echo "Option invalide" ;;
esac
chmod +x menu_hardening.sh

