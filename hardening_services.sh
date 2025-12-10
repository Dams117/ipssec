#!/usr/bin/env bash

# Couleurs
COLOR_INFO="\e[34m"    # bleu
COLOR_OK="\e[32m"      # vert
COLOR_WARN="\e[33m"    # jaune
COLOR_ERROR="\e[31m"   # rouge
COLOR_RESET="\e[0m"

print_info() {
    echo -e "${COLOR_INFO}[INFO]${COLOR_RESET} $*"
}

print_success() {
    echo -e "${COLOR_OK}[OK]${COLOR_RESET} $*"
}

print_warn() {
    echo -e "${COLOR_WARN}[WARN]${COLOR_RESET} $*"
}

print_error() {
    echo -e "${COLOR_ERROR}[ERROR]${COLOR_RESET} $*"
}

disable_unnecessary_services() {
    print_info "=== Disabling Unnecessary Services ==="
    
    services_to_disable=(
        "avahi-daemon"
        "cups"
        "isc-dhcp-server"
        "isc-dhcp-server6"
        "nfs-server"
        "rpcbind"
        "rsync"
        "snmpd"
        "telnet"
        "tftp"
        "vsftpd"
        "xinetd"
    )

    for service in "${services_to_disable[@]}"; do
        if ! systemctl list-unit-files | grep -q "^${service}.service"; then
            print_warn "Service not found (ignored): $service"
            continue
        fi

        echo

        while true; do
            echo -e "${COLOR_INFO}Choix pour le service '${service}' :${COLOR_RESET}"
            echo "  Y = Yes / Oui, désactiver ce service"
            echo "  N = No, laisser ce service tel quel (défaut si tu appuies juste Entrée)"
            read -r -p "$(echo -e "${COLOR_INFO}Votre choix [Y/N] : ${COLOR_RESET}")" answer

            # Entrée vide => NON
            if [ -z "$answer" ]; then
                print_info "Service laissé actif : $service"
                break
            fi

            case "$answer" in
                Y)
                    print_info "Disabling service: $service"
                    if ! systemctl stop "$service" 2>/dev/null; then
                        print_warn "Impossible d'arrêter $service (peut-être déjà arrêté)"
                    fi
                    systemctl disable "$service" 2>/dev/null || print_warn "Impossible de désactiver $service"
                    systemctl mask "$service" 2>/dev/null || print_warn "Impossible de masquer $service"
                    break
                    ;;
                N)
                    print_info "Service laissé actif : $service"
                    break
                    ;;
                *)
                    print_error "Réponse invalide. Merci de répondre par Y ou N."
                    ;;
            esac
        done
    done

    print_success "Traitement des services terminé"
}

disable_unnecessary_services
