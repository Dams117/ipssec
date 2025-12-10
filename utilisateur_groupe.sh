#!/usr/bin/env bash
set -euo pipefail

info(){ echo -e "\e[1;34m[INFO]\e[0m $*"; }
warn(){ echo -e "\e[1;33m[WARN]\e[0m $*"; }
err(){ echo -e "\e[1;31m[ERROR]\e[0m $*" >&2; exit 1; }

# doit être lancé avec sudo
if [ "$EUID" -ne 0 ]; then
err "Ce script doit être exécuté avec sudo. Exécute : sudo /home/aymen/ipsec.sh"
fi

echo "===== Création interactive d'un groupe et d'un utilisateur ====="

# Étape 1 : nom du groupe (optionnel : créer un groupe projet)
while true; do
read -r -p "Nom du groupe à créer (ou groupe existant) : " GROUPNAME
GROUPNAME="${GROUPNAME// /}" # enlever espaces accidentels
if [ -z "$GROUPNAME" ]; then
warn "Nom de groupe vide. Réessaie."
continue
fi
if getent group "$GROUPNAME" > /dev/null; then
info "Le groupe '$GROUPNAME' existe déjà."
read -r -p "Voulez-vous le réutiliser ? (o/n) : " yn
case "${yn,,}" in
o|y) break ;;
n) continue ;;
*) warn "Réponse non reconnue." ;;
esac
else
groupadd "$GROUPNAME"
info "Groupe '$GROUPNAME' créé."
break
fi
done

# Étape 2 : nom de l'utilisateur
while true; do
read -r -p "Nom de l'utilisateur à créer (login, pas d'espaces) : " USERNAME
USERNAME="${USERNAME// /}"
[ -n "$USERNAME" ] || { warn "Nom vide — réessaie."; continue; }
if id -u "$USERNAME" > /dev/null 2>&1; then
warn "L'utilisateur '$USERNAME' existe déjà."
read -r -p "Souhaitez-vous modifier l'utilisateur existant (ajouter groupes) ? (o/n) : " yn
case "${yn,,}" in
o|y) EXISTING_USER=1; break ;;
n) continue ;;
*) warn "Réponse non reconnue." ;;
esac
else
EXISTING_USER=0
break
fi
done

# Étape 3 : groupe principal et groupes secondaires
read -r -p "Groupe principal pour l'utilisateur (laisser vide pour '$GROUPNAME') : " PRIMARY
PRIMARY="${PRIMARY:-$GROUPNAME}"

read -r -p "Groupes supplémentaires (séparés par des virgules), ou laisser vide : " SUPP
SUPP="${SUPP// /}" # retirer espaces

# créer le groupe principal s'il n'existe pas
if ! getent group "$PRIMARY" > /dev/null; then
groupadd "$PRIMARY"
info "Groupe principal '$PRIMARY' créé."
fi

# créer/modifier l'utilisateur
if [ "$EXISTING_USER" -eq 1 ]; then
info "Modification de l'utilisateur '$USERNAME'..."
usermod -g "$PRIMARY" "$USERNAME" || true
[ -n "$SUPP" ] && usermod -aG "$SUPP" "$USERNAME" || true
else
info "Création de l'utilisateur '$USERNAME'..."
if [ -n "$SUPP" ]; then
useradd -m -s /bin/bash -g "$PRIMARY" -G "$SUPP" "$USERNAME"
else
useradd -m -s /bin/bash -g "$PRIMARY" "$USERNAME"
fi
info "Utilisateur créé avec home /home/$USERNAME"
fi

# mot de passe — boucle jusqu'à confirmation non vide
while true; do
echo "Définir le mot de passe pour $USERNAME."
read -s -r -p "Mot de passe : " PASS1; echo
read -s -r -p "Confirmer mot de passe : " PASS2; echo
if [ -z "$PASS1" ]; then
warn "Mot de passe vide interdit."
continue
fi
if [ "$PASS1" != "$PASS2" ]; then
warn "Les mots de passe ne correspondent pas. Réessaie."
continue
fi
echo "$USERNAME:$PASS1" | chpasswd
info "Mot de passe défini."
break
done

# forcer le changement au premier login (optionnel)
read -r -p "Forcer changement du mot de passe au premier login ? (o/n) : " ch
case "${ch,,}" in
o|y) chage -d 0 "$USERNAME"; info "Changement forcé au premier login." ;;
*) info "Changement non forcé." ;;
esac

# option sudo
read -r -p "Ajouter l'utilisateur au groupe 'sudo' (droits admin) ? (o/n) : " sudoans
case "${sudoans,,}" in
o|y)
usermod -aG sudo "$USERNAME"
info "Utilisateur $USERNAME ajouté au groupe sudo."
;;
*) info "Utilisateur non ajouté au sudo." ;;
esac

# vérifications finales
echo
info "Vérifications finales :"
id "$USERNAME"
echo
info "Terminé. Vérifie /home/$USERNAME et les groupes avec 'id $USERNAME' ou 'getent group $GROUPNAME'."
