#!/bin/bash

# Vérifier si le script est lancé en root
if [ "$EUID" -ne 0 ]; then 
    echo "ERREUR : Ce script doit être exécuté avec sudo"
    exit 1
fi

clear
echo "================================"
echo "Assistant AppArmor"
echo "================================"
echo ""

# Expliquer AppArmor
echo "AppArmor est un système de sécurité Linux."
echo "Il contrôle ce que vos programmes peuvent faire."
echo ""
echo "Exemples :"
echo "  - Bloquer l'accès aux mots de passe"
echo "  - Empêcher l'accès à vos documents"
echo "  - Limiter l'accès Internet"
echo ""
read -p "Appuyez sur Entrée pour continuer..."
echo ""

# Vérifier si AppArmor est installé
echo "Vérification d'AppArmor..."

if command -v aa-status &> /dev/null; then
    echo "✓ AppArmor est installé"
else
    echo "AppArmor n'est pas installé."
    read -p "Voulez-vous l'installer ? (o/n) : " reponse
    
    if [ "$reponse" = "o" ] || [ "$reponse" = "O" ]; then
        echo "Installation en cours..."
        apt update
        apt install -y apparmor apparmor-utils
        echo "✓ Installation terminée"
    else
        echo "Installation annulée."
        exit 0
    fi
fi

echo ""
read -p "Voulez-vous créer un profil de sécurité ? (o/n) : " creer

if [ "$creer" != "o" ] && [ "$creer" != "O" ]; then
    echo "Au revoir !"
    exit 0
fi

# Demander le programme à protéger
echo ""
read -p "Chemin du programme à protéger : " chemin_programme

if [ ! -f "$chemin_programme" ]; then
    echo "ERREUR : Le fichier n'existe pas !"
    exit 1
fi

echo "✓ Programme trouvé"
chmod +x "$chemin_programme"

# Questions simples
echo ""
echo "Configuration des permissions :"
echo ""

read -p "Accès Internet ? (o/n) : " internet
read -p "Accès aux Documents ? (o/n) : " documents
read -p "Accès aux Téléchargements ? (o/n) : " telechargements
read -p "Accès aux clés SSH ? (o/n) : " ssh
read -p "Accès à /etc/shadow ? (o/n) : " shadow

# Résumé
echo ""
echo "================================"
echo "Résumé"
echo "================================"
echo "Programme : $chemin_programme"
echo "Internet : $internet"
echo "Documents : $documents"
echo "Téléchargements : $telechargements"
echo "Clés SSH : $ssh"
echo "/etc/shadow : $shadow"
echo ""

read -p "Créer ce profil ? (o/n) : " confirmer

if [ "$confirmer" != "o" ] && [ "$confirmer" != "O" ]; then
    echo "Annulé."
    exit 0
fi

# Créer le profil
nom_profil=$(echo "$chemin_programme" | sed 's/\//_/g' | sed 's/^_//')
fichier_profil="/etc/apparmor.d/$nom_profil"

# Supprimer l'ancien profil si existe
if [ -f "$fichier_profil" ]; then
    aa-disable "$chemin_programme" 2>/dev/null
    rm -f "$fichier_profil"
fi

# Générer le profil
cat > "$fichier_profil" << EOF
#include <tunables/global>

$chemin_programme {
  #include <abstractions/base>
  #include <abstractions/bash>
  
  $chemin_programme r,
EOF

# Internet
if [ "$internet" = "o" ] || [ "$internet" = "O" ]; then
    echo "  #include <abstractions/nameservice>" >> "$fichier_profil"
    echo "  network inet stream," >> "$fichier_profil"
    echo "  network inet6 stream," >> "$fichier_profil"
fi

# Documents
if [ "$documents" = "o" ] || [ "$documents" = "O" ]; then
    echo "  owner @{HOME}/Documents/** rw," >> "$fichier_profil"
fi

# Téléchargements
if [ "$telechargements" = "o" ] || [ "$telechargements" = "O" ]; then
    echo "  owner @{HOME}/Downloads/** rw," >> "$fichier_profil"
    echo "  owner @{HOME}/Téléchargements/** rw," >> "$fichier_profil"
fi

# SSH
if [ "$ssh" = "o" ] || [ "$ssh" = "O" ]; then
    echo "  owner @{HOME}/.ssh/** r," >> "$fichier_profil"
else
    echo "  deny @{HOME}/.ssh/** rw," >> "$fichier_profil"
fi

# Shadow
if [ "$shadow" = "o" ] || [ "$shadow" = "O" ]; then
    echo "  /etc/shadow r," >> "$fichier_profil"
else
    echo "  deny /etc/shadow rw," >> "$fichier_profil"
fi

echo "}" >> "$fichier_profil"

# Charger le profil
echo ""
echo "Chargement du profil..."
apparmor_parser -r "$fichier_profil"
aa-enforce "$chemin_programme" 2>/dev/null

echo "✓ Profil activé en mode strict !"
echo ""
echo "Vérifiez avec : sudo aa-status"
