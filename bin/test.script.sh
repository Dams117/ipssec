#!/bin/bash


Protocol_UDP=(67 68 161 162 )
Protocol_TCP=(23 25 143 3306 5432 80 443 8080)
LISTE_TCP=" ${Protocol_TCP[*]} "
LISTE_UDP=" ${Protocol_UDP[*]} "


menu() {
    echo "--------------------------------------------------------"
    echo "--------------## MENU PRINCIPAL ##----------------------"
    echo "-------------###FireWall/Pare-feu###--------------------"
    echo "--------------------------------------------------------"
    echo "Options disponibles :"
    echo " -m : Instalation de Iptable + Configuration des port"
    echo " -i : Bloquage des Ip"
    echo " -a : Option 3"
    echo " -u : Option 4"
    echo " -w : QUITTER le script."
    echo "--------------------------------------------------------"
    read -p "Veuillez choisir une option : " Option
}


while [[ "$Option" != "-w" ]]; do
    menu

    echo "Argument fourni : $Option"
    echo "--- Début du traitement ---"

    case "$Option" in
        "-m")
            echo "Demarage de la configuration Iptables.."
            sudo iptables -F
            sudo iptables -X
            sudo iptables -Z
            echo "Suppression des anciennes règles Iptables."

            sudo iptables -P INPUT DROP

            sudo iptables -P FORWARD DROP

            sudo iptables -P OUTPUT ACCEPT

            echo "Mise en place de regle essentielles"

            sudo iptables -A INPUT -i lo -j ACCEPT
            sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        
            echo "Configuration de base de Iptables effectuer"
            echo " "
            echo " "

            echo " ## Creation de la  liste blanche ## "
		    read -p "Quelle type de protocol utilise le service de votre Port ? (UDP ou TCP) " NomProtocole
            echo " "
            if [[ $NomProtocole == "UDP" ]]; then
	            read -p "quelle port voullez allow : " Nomduport
		        if [[ "$LISTE_UDP" =~ " $Nomduport " ]]; then
		
		            sudo iptables -A INPUT -p udp --dport "$Nomduport" -j ACCEPT
		            echo "Succès :Règle Iptables ajoutée : $Nomduport/UDP autorisé.."
		        else
		        echo "Échec : $Nomduport non trouvé."
		    fi
	
            elif [[ $NomProtocole == "TCP" ]]; then
	            read -p "quelle port voullez allow : " Nomduport
		        if [[ "$LISTE_TCP" =~ " $Nomduport " ]]; then
		            sudo iptables -A INPUT -p tcp --dport "$Nomduport" -j ACCEPT		
		            echo "Succès Règle Iptables ajoutée : $Nomduport/TCP autorisé.."
		        else
		            echo "Échec : $Nomduport non trouvé."
		        fi
            else
		        echo "commande non valide.... veuillier entrez UDP ou TCP" 

            fi 

            echo "Mise en place de la SAVE..."
            echo "Check de l'instalation de netfilter-persistent... "
            
            if command -v netfilter-persistent &> /dev/null; then
                echo "  'outil de persistance est installé."
            else
                # Installation si manquant
                echo "   'netfilter-persistent' est manquant. Installation en cours..."
                sudo apt update > /dev/null 2>&1
                sudo apt install -y netfilter-persistent
            
            
            if ! command -v netfilter-persistent &> /dev/null; then
                echo "   [ERREUR FATALE] L'installation a échoué ou l'outil n'est pas dans le PATH."
                echo "   La persistance des règles ne peut être garantie."
                exit 1
            fi
            echo "   Installation réussie."
        fi
        
        # Sauvegarde finale
        sudo netfilter-persistent save
        echo "    Règles Iptables sauvegardées pour persistance au redémarrage."


        ;;
		"-i")
        echo "option2"

        ;;

        "-a")
        echo "option3"

        ;;

        "-u")
        echo "option4"

        ;;

        "-w")
        echo " Au revoir "
        break

        ;;

        *)
        echo "ERREUR : '$Option'  non reconnue."
        echo "euillez choisir une option du menu"
        
        ;;
esac

echo "---"
echo "Fin du traitement."

done
