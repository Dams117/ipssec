# IPSSEC - Sécurisation et de Durcissement Linux

## Description

Ce projet regroupe un ensemble de scripts Bash modulaires destinés à l'automatisation, au durcissement (hardening) et à l'audit de systèmes Linux (principalement Debian/Ubuntu). Il offre des outils pour configurer le réseau, le pare-feu, le chiffrement, gérer les utilisateurs et appliquer des politiques d'audit de sécurité strictes, inspirées des recommandations de l'ANSSI.

## Avertissement Important

Ces scripts modifient des fichiers de configuration système critiques (SSH, GRUB, Sysctl, PAM, Iptables).
* **Environnement de test** : Il est impératif de tester ces outils dans un environnement non critique avant tout déploiement en production.
* **Sauvegardes** : Assurez-vous de disposer de sauvegardes à jour de votre système.
* **Privilèges** : L'exécution nécessite les droits administrateur (root).

## Fonctionnalités

Le projet couvre plusieurs domaines de la sécurité système :

### 1. Sécurité Réseau et Pare-feu
* **Pare-feu Avancé (BrainFW)** :
    * Gestion complète des règles `iptables` IPv4 avec persistance.
    * Politique restrictive par défaut (DROP).
    * Protections intégrées : Anti-DDoS, Anti-Portscan, Anti-Brute-force.
    * Mode interactif pour l'ouverture/fermeture de ports.
    * Blocage géographique (GeoIP) et par IP/CIDR.
* **Durcissement Noyau (Sysctl)** :
    * Application de paramètres de sécurité réseau via `sysctl.conf`.
    * Protections IPv4 (SYN cookies, RP Filter).
    * Désactivation ou sécurisation de l'IPv6.
    * Restriction d'accès aux logs noyau (`dmesg`) et protection contre les attaques via liens symboliques.

### 2. Gestion et Sécurisation SSH
* **Automatisation** : Installation du service et génération automatique de paires de clés (Ed25519 ou RSA 4096 bits).
* **Hardening** :
    * Modification de `sshd_config` pour désactiver l'authentification par mot de passe et le login root.
    * Changement de port SSH optionnel.

### 3. Sécurité Système et Amorçage
* **Sécurisation GRUB** : Définition d'un superutilisateur, chiffrement du mot de passe (PBKDF2) et restriction des permissions sur les fichiers de configuration.
* **AppArmor** : Assistant interactif pour la création de profils de sécurité par application (restriction réseau, fichiers, etc.).
* **Restriction des Privilèges** : Limitation de l'usage de la commande `su` aux seuls membres du groupe sudo via PAM.

### 4. Gestion des Utilisateurs et Audit
* **Création d'Utilisateurs** : Script de création en masse d'utilisateurs sudo avec vérification des UID disponibles et validation des noms.
* **Audit Système** :
    * Installation et configuration de `auditd`.
    * Application de règles d'audit ANSSI (surveillance des fichiers critiques, exécution de commandes, montages, modules noyau).
* **Mises à jour** : Automatisation des mises à jour système et activation de `unattended-upgrades`.

## Structure du Projet

* `bin/` : Contient les scripts exécutables et les points d'entrée.
    * `src/` : Code source des différents modules.
        * `reseau/` : Scripts de configuration réseau et SSH.
        * `securite/` : Scripts pour le pare-feu, GRUB et AppArmor.
        * `menu/` : Interfaces de menus interactifs.
        * `ipssec.sh` : Script principal pour l'audit et les mises à jour.
        * `root.sh` : Script de restriction PAM.

## Utilisation

1.  Rendez les scripts exécutables :
    ```bash
    chmod +x bin/main.sh
    chmod -R +x bin/src/
    chmod +x *.sh
    ```

2.  Lancez le script principal ou les modules individuels avec les droits root :
    ```bash
    sudo ./bin/main.sh
    ```
    Ou pour un module spécifique (exemple pare-feu) :
    ```bash
    sudo ./bin/src/securite/FireWallconf.sh interactive
    ```