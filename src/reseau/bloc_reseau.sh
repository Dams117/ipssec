#!/bin/bash

if [ "$EUID" -ne 0 ]; then
    echo "Ce script doit être exécuté en root."
    exit 1
fi

SYSCTL_FILE="/etc/sysctl.conf"

# Fonction O/N
ask_yes_no() {
    local answer
    while true; do
        read -rp "$1 [o/n] : " answer
        case "$answer" in
            o|O) return 0 ;;
            n|N) return 1 ;;
            *) echo "Réponse invalide, merci de répondre par o ou n." ;;
        esac
    done
}

echo "==> Configuration des paramètres réseau (sysctl) et IPv6..."

# Sauvegarde avant modification
cp "$SYSCTL_FILE" "${SYSCTL_FILE}.bak"

# On nettoie / recrée la fin du fichier à partir d’un marqueur
echo "" >> "$SYSCTL_FILE"
echo "# ===== Début configuration hardening réseau =====" >> "$SYSCTL_FILE"

############################
# 1) Protection IPv4
############################
if ask_yes_no "Appliquer les protections IPv4 (SYN cookies, rp_filter, ICMP, redirects) ?"; then
    cat <<'EOF' >> "$SYSCTL_FILE"
# 1) Protection IPv4

net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
EOF
else
    echo "# Bloc IPv4 non appliqué" >> "$SYSCTL_FILE"
fi

############################
# 2) IPv6
############################
if ask_yes_no "Désactiver / durcir IPv6 ?"; then
    cat <<'EOF' >> "$SYSCTL_FILE"
# 2) Durcissement IPv6

net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
net.ipv6.conf.all.accept_ra = 0
net.ipv6.conf.default.accept_ra = 0
EOF
else
    echo "# Bloc IPv6 non appliqué" >> "$SYSCTL_FILE"
fi

############################
# 3) Comportement noyau réseau
############################
if ask_yes_no "Durcir le comportement noyau (ip_forward, tcp_max_orphans, kptr/dmesg) ?"; then
    cat <<'EOF' >> "$SYSCTL_FILE"
# 3) Comportement réseau du noyau

net.ipv4.ip_forward = 0
net.ipv6.conf.all.forwarding = 0
net.ipv4.tcp_max_orphans = 8192
kernel.kptr_restrict = 1
kernel.dmesg_restrict = 1
EOF
else
    echo "# Bloc noyau réseau non appliqué" >> "$SYSCTL_FILE"
fi

############################
# 4) FS symlinks / hardlinks
############################
if ask_yes_no "Appliquer les protections symlinks / hardlinks (FS) ?"; then
    cat <<'EOF' >> "$SYSCTL_FILE"
# 4) Divers durcissements noyau (FS)

fs.protected_hardlinks = 1
fs.protected_symlinks  = 1
EOF
else
    echo "# Bloc FS non appliqué" >> "$SYSCTL_FILE"
fi

echo "# ===== Fin configuration hardening réseau =====" >> "$SYSCTL_FILE"

echo "==> Application des paramètres sysctl..."
sysctl -p "$SYSCTL_FILE"

echo "==> Terminé. Sauvegarde dispo : ${SYSCTL_FILE}.bak"
