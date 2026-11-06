#!/usr/bin/env bash
# À lancer sur hci1 en tant que hci.
set -euo pipefail
[ "$(whoami)" = hci ] || { echo "Lancer en tant que hci"; exit 1; }
sudo apt update
sudo DEBIAN_FRONTEND=noninteractive apt install -y ansible git sshpass
cd ~/hci-poc
[ -f files/hci_id_ed25519 ] || ssh-keygen -t ed25519 -N '' -f files/hci_id_ed25519
chmod +x files/hcictl
ip -br a
echo "Vérifier que if_priv/if_uplink/if_vm de group_vars/all.yml correspondent."
