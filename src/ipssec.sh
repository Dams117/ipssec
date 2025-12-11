#!/bin/bash
echo "==== Configuration de la sécurité & journalisation ===="
echo

### --- 0. Vérification root ---
if [[ $EUID -ne 0 ]]; then
    echo "[ERREUR] Ce script doit être exécuté en root."
    exit 1
fi


### --- 1. Installation auditd ---
read -p "Voulez-vous installer et activer auditd ? (o/n) : " use_audit
if [[ "$use_audit" =~ ^[oO]$ ]]; then
    echo "[+] Installation d'auditd..."
    apt-get update -y
    apt-get install -y auditd audispd-plugins
    systemctl enable auditd
    systemctl start auditd
    echo "[OK] auditd installé et activé."
    echo


    ### --- 2. Menu des règles audit ANSSI ---
    echo "=== Sélectionnez les règles d'audit à appliquer ==="
    echo "1) Audit fichiers systèmes sensibles"
    echo "2) Audit sudo / privilèges"
    echo "3) Audit logs (/var/log)"
    echo "4) Audit commandes exécutées (execve)"
    echo "5) Audit événements systèmes ANSSI (time, mounts, kernel, network …)"
    echo "6) TOUT appliquer (pack ANSSI complet)"
    echo
    read -p "Choix (ex: 1 4 5) : " audit_choices

    RULEFILE="/etc/audit/rules.d/custom.rules"
    echo "" > "$RULEFILE"

    for choix in $audit_choices; do
        case $choix in
        
            ### --- 1. FICHIERS SYSTÈME SENSIBLES ---
            1)
                echo "# Règle 1 : fichiers sensibles"                     >> "$RULEFILE"
                echo "-w /etc/passwd -p wa -k passwd_changes"             >> "$RULEFILE"
                echo "-w /etc/shadow -p wa -k shadow_changes"             >> "$RULEFILE"
                echo "-w /etc/group -p wa -k group_changes"               >> "$RULEFILE"
                echo "-w /etc/gshadow -p wa -k gshadow_changes"           >> "$RULEFILE"
                echo "-w /etc/security/ -p wa -k security_conf"           >> "$RULEFILE"
                ;;

            ### --- 2. SUDO / PRIVILÈGES ---
            2)
                echo "# Règle 2 : sudo"                                   >> "$RULEFILE"
                echo "-w /etc/sudoers -p wa -k sudo_edit"                 >> "$RULEFILE"
                echo "-w /etc/sudoers.d/ -p wa -k sudo_edit"              >> "$RULEFILE"
                echo "-w /var/log/auth.log -p wa -k auth_logs"            >> "$RULEFILE"
                ;;

            ### --- 3. LOGS ---
            3)
                echo "# Règle 3 : logs"                                   >> "$RULEFILE"
                echo "-w /var/log/ -p wa -k log_access"                   >> "$RULEFILE"
                ;;

            ### --- 4. COMMANDES EXÉCUTÉES ---
            4)
                echo "# Règle 4 : execve"                                 >> "$RULEFILE"
                echo "-a always,exit -F arch=b64 -S execve -k commands"   >> "$RULEFILE"
                ;;

            ### --- 5. RÈGLES ANSSI COMPLÈTES ---
            5)
                echo "# Règle 5 : événements système ANSSI"               >> "$RULEFILE"
                
                # Changement d'heure
                echo "-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change" >> "$RULEFILE"

                # Montages
                echo "-a always,exit -F arch=b64 -S mount -S umount2 -k mounts"             >> "$RULEFILE"

                # Kernel modules
                echo "-w /sbin/insmod -p x -k modules"                    >> "$RULEFILE"
                echo "-w /sbin/modprobe -p x -k modules"                  >> "$RULEFILE"
                echo "-w /sbin/rmmod -p x -k modules"                     >> "$RULEFILE"
                
                # Réseaux
                echo "-w /etc/hosts -p wa -k network_conf"                >> "$RULEFILE"
                echo "-w /etc/network/ -p wa -k network_conf"             >> "$RULEFILE"

                # Accès root shell
                echo "-w /bin/su -p x -k root_shell"                      >> "$RULEFILE"
                ;;

            ### --- 6. PACK COMPLET ---
            6)
                echo "# PACK COMPLET ANSSI"                               >> "$RULEFILE"

                # Fichiers sensibles
                echo "-w /etc/passwd -p wa -k passwd_changes"             >> "$RULEFILE"
                echo "-w /etc/shadow -p wa -k shadow_changes"             >> "$RULEFILE"
                echo "-w /etc/group -p wa -k group_changes"               >> "$RULEFILE"
                echo "-w /etc/gshadow -p wa -k gshadow_changes"           >> "$RULEFILE"

                # Sudo
                echo "-w /etc/sudoers -p wa -k sudo_edit"                 >> "$RULEFILE"
                echo "-w /etc/sudoers.d/ -p wa -k sudo_edit"              >> "$RULEFILE"

                # Logs
                echo "-w /var/log/ -p wa -k log_access"                   >> "$RULEFILE"

                # Execve
                echo "-a always,exit -F arch=b64 -S execve -k commands"   >> "$RULEFILE"

                # Time change
                echo "-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time_change" >> "$RULEFILE"

                # Montages
                echo "-a always,exit -F arch=b64 -S mount -S umount2 -k mounts"              >> "$RULEFILE"

                # Kernel modules
                echo "-w /sbin/insmod -p x -k modules"                    >> "$RULEFILE"
                echo "-w /sbin/modprobe -p x -k modules"                  >> "$RULEFILE"
                echo "-w /sbin/rmmod -p x -k modules"                     >> "$RULEFILE"
                ;;

            *)
                echo "[!] Option inconnue : $choix"
                ;;
        esac
    done


    ### --- 3. Chargement des règles ---
    echo "[+] Chargement des règles..."
    augenrules --load
    echo "[OK] Règles auditd chargées."
    echo
fi


### --- 4. Mises à jour automatiques ---
read -p "Activer les mises à jour automatiques de sécurité ? (o/n) : " maj
if [[ "$maj" =~ ^[oO]$ ]]; then
    apt-get install -y unattended-upgrades
    dpkg-reconfigure -plow unattended-upgrades
    apt full-upgrade
    echo "[OK] Mises à jour automatiques activées."
else
    echo "[-] Mises à jour automatiques non activées."
fi
### --- 4. Mise à jour complète du système ---
read -p "Souhaitez-vous mettre à jour complètement le système maintenant ? (o/n) : " maj_sys
if [[ "$maj_sys" =~ ^[oO]$ ]]; then
    echo "[+] Mise à jour du système..."
    apt-get update -y
    apt-get upgrade -y
    apt-get full-upgrade -y
    apt-get autoremove -y
    apt-get autoclean -y
    echo "[OK] Système mis à jour."
else
    echo "[-] Mise à jour du système ignorée."
fi
echo


echo
echo "==== Configuration terminée ===="






