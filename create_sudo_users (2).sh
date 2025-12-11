#!/bin/bash

# Script de création d'utilisateurs sudo
# Vérifie les UID disponibles et crée les comptes avec les droits administrateur

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Plage d'UID pour les utilisateurs normaux (généralement 1000-60000 sur la plupart des distributions)
UID_MIN=1000
UID_MAX=60000

# Vérifier que le script est exécuté en root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Erreur : Ce script doit être exécuté en tant que root (sudo).${NC}"
    exit 1
fi

# Fonction pour compter les UID disponibles
count_available_uids() {
    local used_uids=$(getent passwd | awk -F: -v min="$UID_MIN" -v max="$UID_MAX" '$3 >= min && $3 <= max {print $3}' | sort -n)
    local total_possible=$((UID_MAX - UID_MIN + 1))
    local used_count=$(echo "$used_uids" | grep -c .)
    
    # Si aucun UID utilisé, used_count sera 1 à cause de grep -c sur ligne vide
    if [[ -z "$used_uids" ]]; then
        used_count=0
    fi
    
    echo $((total_possible - used_count))
}

# Fonction pour vérifier si un UID est disponible
is_uid_available() {
    local uid=$1
    # Vérifier que l'UID est dans la plage autorisée
    if [[ $uid -lt $UID_MIN || $uid -gt $UID_MAX ]]; then
        return 1
    fi
    # Vérifier si l'UID est déjà utilisé
    if getent passwd | awk -F: '{print $3}' | grep -q "^${uid}$"; then
        return 1  # UID utilisé
    fi
    return 0  # UID disponible
}

# Fonction pour trouver le prochain UID disponible à partir d'un point de départ
find_next_available_uid() {
    local start_uid=${1:-$UID_MIN}
    local uid=$start_uid
    
    while [[ $uid -le $UID_MAX ]]; do
        if is_uid_available $uid; then
            echo $uid
            return 0
        fi
        ((uid++))
    done
    
    # Aucun UID disponible trouvé
    echo -1
    return 1
}

# Fonction pour valider un nom d'utilisateur
validate_username() {
    local username="$1"
    
    # Vérifier que le nom n'est pas vide
    if [[ -z "$username" ]]; then
        echo "Le nom d'utilisateur ne peut pas être vide."
        return 1
    fi
    
    # Vérifier la longueur (max 32 caractères)
    if [[ ${#username} -gt 32 ]]; then
        echo "Le nom d'utilisateur ne doit pas dépasser 32 caractères."
        return 1
    fi
    
    # Vérifier que le nom commence par une lettre minuscule ou underscore
    if [[ ! "$username" =~ ^[a-z_] ]]; then
        echo "Le nom doit commencer par une lettre minuscule ou un underscore."
        return 1
    fi
    
    # Vérifier les caractères autorisés (lettres minuscules, chiffres, underscore, tiret)
    if [[ ! "$username" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
        echo "Le nom ne doit contenir que des lettres minuscules, chiffres, underscores ou tirets."
        return 1
    fi
    
    # Vérifier que l'utilisateur n'existe pas déjà
    if id "$username" &>/dev/null; then
        echo "L'utilisateur '$username' existe déjà."
        return 1
    fi
    
    return 0
}

# Affichage du titre
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   Création d'utilisateurs administrateurs  ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""

# Afficher le nombre d'UID disponibles
available_uids=$(count_available_uids)
echo -e "${YELLOW}Information :${NC} $available_uids UID disponibles dans la plage $UID_MIN-$UID_MAX"
echo ""

# Demander le nombre d'utilisateurs à créer
while true; do
    read -p "Combien d'utilisateurs sudo souhaitez-vous créer ? " user_count
    
    # Vérifier que c'est un nombre entier positif
    if [[ ! "$user_count" =~ ^[0-9]+$ ]]; then
        echo -e "${RED}Erreur : Veuillez entrer un nombre entier positif.${NC}"
        continue
    fi
    
    # Vérifier que ce n'est pas zéro
    if [[ "$user_count" -eq 0 ]]; then
        echo -e "${RED}Erreur : Veuillez entrer un nombre supérieur à 0.${NC}"
        continue
    fi
    
    # Vérifier qu'il y a assez d'UID disponibles
    if [[ "$user_count" -gt "$available_uids" ]]; then
        echo -e "${RED}Erreur : Pas assez d'UID disponibles.${NC}"
        echo -e "${RED}Vous souhaitez créer $user_count utilisateurs mais il n'y a que $available_uids UID disponibles.${NC}"
        continue
    fi
    
    break
done

echo ""
echo -e "${GREEN}Vous allez créer $user_count utilisateur(s) sudo.${NC}"
echo ""

# Tableau pour stocker les noms d'utilisateurs
declare -a usernames

# Demander les noms d'utilisateurs
for ((i=1; i<=user_count; i++)); do
    while true; do
        read -p "Utilisateur sudo $i : " username
        
        # Convertir en minuscules et supprimer les espaces
        username=$(echo "$username" | tr '[:upper:]' '[:lower:]' | tr -d ' ')
        
        # Valider le nom d'utilisateur
        error_msg=$(validate_username "$username")
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}Erreur : $error_msg${NC}"
            continue
        fi
        
        # Vérifier que le nom n'est pas déjà dans notre liste
        for existing in "${usernames[@]}"; do
            if [[ "$existing" == "$username" ]]; then
                echo -e "${RED}Erreur : Ce nom est déjà dans la liste des utilisateurs à créer.${NC}"
                continue 2
            fi
        done
        
        usernames+=("$username")
        break
    done
done

# Récapitulatif
echo ""
echo -e "${YELLOW}============================================${NC}"
echo -e "${YELLOW}           Récapitulatif                    ${NC}"
echo -e "${YELLOW}============================================${NC}"
echo ""
echo "Les utilisateurs suivants vont être créés avec les droits sudo :"
for ((i=0; i<${#usernames[@]}; i++)); do
    echo "  $((i+1)). ${usernames[$i]}"
done
echo ""

# Demander confirmation
while true; do
    read -p "Confirmer la création ? (o/n) : " confirm
    if [[ "$confirm" =~ ^[oOyY]$ ]]; then
        break
    elif [[ "$confirm" =~ ^[nN]$ ]]; then
        echo -e "${YELLOW}Opération annulée.${NC}"
        exit 0
    else
        echo -e "${RED}Erreur : Veuillez répondre par 'o' (oui) ou 'n' (non).${NC}"
    fi
done

echo ""

# Créer les utilisateurs
created_count=0
next_uid=$UID_MIN

for username in "${usernames[@]}"; do
    echo -n "Recherche d'un UID disponible pour '$username'... "
    
    # Boucler jusqu'à trouver un UID libre
    while true; do
        if is_uid_available $next_uid; then
            echo -e "${GREEN}UID $next_uid disponible.${NC}"
            break
        else
            echo -n "UID $next_uid occupé, "
            ((next_uid++))
            
            # Vérifier qu'on n'a pas dépassé la limite
            if [[ $next_uid -gt $UID_MAX ]]; then
                echo -e "${RED}Plus d'UID disponibles !${NC}"
                echo -e "${RED}Impossible de créer l'utilisateur '$username'.${NC}"
                continue 2  # Passer à l'utilisateur suivant
            fi
        fi
    done
    
    echo -n "Création de l'utilisateur '$username' avec UID $next_uid... "
    
    # Créer l'utilisateur avec l'UID spécifique et un home directory
    if useradd -m -s /bin/bash -u "$next_uid" "$username" 2>/dev/null; then
        # Ajouter au groupe sudo
        if usermod -aG sudo "$username" 2>/dev/null; then
            # Définir un mot de passe (boucle jusqu'à succès)
            while true; do
                echo ""
                echo -e "${YELLOW}Définissez le mot de passe pour '$username' :${NC}"
                passwd "$username"
                
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}✓ Utilisateur '$username' (UID: $next_uid) créé avec succès et ajouté au groupe sudo.${NC}"
                    ((created_count++))
                    ((next_uid++))  # Incrémenter pour le prochain utilisateur
                    break
                else
                    echo -e "${RED}✗ Les mots de passe ne correspondent pas ou sont trop faibles. Veuillez réessayer.${NC}"
                fi
            done
        else
            echo -e "${RED}✗ Erreur lors de l'ajout au groupe sudo.${NC}"
            # Supprimer l'utilisateur créé si l'ajout sudo échoue
            userdel -r "$username" 2>/dev/null
        fi
    else
        echo -e "${RED}✗ Erreur lors de la création de l'utilisateur.${NC}"
        ((next_uid++))  # Essayer le prochain UID pour le prochain utilisateur
    fi
done

# Résumé final
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}           Résumé                           ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "Utilisateurs créés avec succès : ${GREEN}$created_count${NC} / $user_count"

if [[ $created_count -gt 0 ]]; then
    echo ""
    echo "Les nouveaux utilisateurs peuvent se connecter avec :"
    echo "  su - <nom_utilisateur>"
    echo ""
    echo "Ils peuvent utiliser sudo pour les commandes administrateur."
fi

echo ""
exit 0
