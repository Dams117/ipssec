#!/bin/bash

###############################################
# Installation automatique de SSH
###############################################
installer_ssh() {

    echo "----- Installation de SSH -----"
    read -p "Voulez-vous installer SSH ? (yes/no) : " SSHinstall

    if [ "$SSHinstall" != "yes" ] && [ "$SSHinstall" != "no" ]; then
        echo "Erreur : veuillez répondre par yes ou no."
        return
    fi

    if [ "$SSHinstall" = "yes" ]; then
        echo "Installation de SSH en cours..."
        sudo apt update -y && sudo apt install ssh -y
        sudo systemctl enable ssh
        sudo systemctl start ssh
        echo "SSH a été installé avec succès."
    else
        echo "Installation annulée."
    fi
}

###############################################
# Génération automatique des clés SSH
###############################################
generer_key() {

    echo "----- Génération de clés SSH -----"
    read -p "Voulez-vous générer une paire de clés SSH ? (yes/no) : " reponse

    # Vérification de la réponse
    if [ "$reponse" != "yes" ] && [ "$reponse" != "no" ]; then
        echo "Erreur : veuillez répondre par yes ou no."
        return
    fi

    if [ "$reponse" = "no" ]; then
        echo "Génération des clés annulée."
        return
    fi

    # Choix du type de clé
    echo "Quel type de clé voulez-vous générer ?"
    echo "1) ed25519 (recommandé)"
    echo "2) rsa 4096 bits"
    read -p "Votre choix : " choix

    if [ "$choix" = "1" ]; then
        type="ed25519"
        fichier="id_ed25519"
    elif [ "$choix" = "2" ]; then
        type="rsa"
        fichier="id_rsa"
    else
        echo "Choix invalide."
        return
    fi

    # Création du dossier .ssh s'il n'existe pas
    if [ ! -d "$HOME/.ssh" ]; then
        mkdir "$HOME/.ssh"
        chmod 700 "$HOME/.ssh"
        echo "Dossier .ssh créé."
    fi

    # Génération de la clé
    echo "Création de la clé..."
    ssh-keygen -t $type -b 4096 -f "$HOME/.ssh/$fichier" -N "" >/dev/null 2>&1

    # Permissions
    chmod 600 "$HOME/.ssh/$fichier"
    chmod 644 "$HOME/.ssh/$fichier.pub"

    echo "Clé privée : $HOME/.ssh/$fichier"
    echo "Clé publique : $HOME/.ssh/$fichier.pub"
    echo "Génération des clés terminée."
}

###############################################
# Sécurisation SSH
###############################################
securiser_ssh() {

    echo "----- Sécurisation de SSH -----"

    SSHD="/etc/ssh/sshd_config"

    # Sauvegarde
    sudo cp $SSHD $SSHD.bak
    echo "Backup de sshd_config créé : $SSHD.bak"

    # Désactiver connexion root
    sudo sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' $SSHD

    # Désactiver connexion par mot de passe
    sudo sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' $SSHD

    # Autoriser uniquement les clés
    sudo sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' $SSHD

    # Désactiver ChallengeResponse
    sudo sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' $SSHD

     # Changer le port SSH
    read -p "Voulez-vous changer le port SSH (défaut 22) ? (yes/no) : " choix_port

    if [ "$choix_port" != "yes" ] && [ "$choix_port" != "no" ]; then
        echo "Erreur : veuillez répondre par yes ou no."
        return
    fi

    if [ "$choix_port" = "yes" ]; then
        read -p "Nouveau port SSH : " newport
        sudo sed -i "s/^#\?Port.*/Port $newport/" $SSHD
        echo "Port SSH changé en $newport. Pensez à l'ouvrir dans le firewall."
    fi
}

###############################################
# menu pour tester le script
###############################################

while true
do
    echo "=== Menu SSH ==="
    echo "1) Installer SSH"
    echo "2) Générer une clé SSH"
    echo "3) Sécuriser SSH"
    echo "4) Tout faire"
    echo "5) Passer à la suite"
    read -p "Choix : " choix

    case $choix in
        1) installer_ssh ;;
        2) generer_key ;;
        3) securiser_ssh ;;
        4) installer_ssh ; generer_key ; securiser_ssh ;;
        5) break ;
    esac
done

    echo "redémarrage de ssh"
    sudo systemctl restart ssh
    echo "ssh à bien redémarrer"

