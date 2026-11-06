#!/usr/bin/env bash
# A lancer sur pve (root). CrÃ©e l'utilisateur hci s'il n'existe pas et force son mot de passe.
apt install -y sshpass
for ip in 10.10.10.11 10.10.10.12 10.10.10.13; do
  sshpass -p azerty1234 ssh -o StrictHostKeyChecking=accept-new ubuntu@$ip \
    "echo azerty1234 | sudo -S sh -c 'id hci >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo hci; echo hci:azerty1234 | chpasswd; usermod -aG sudo hci' && echo \"$ip : hci OK\""
done
for ip in 10.10.10.11 10.10.10.12 10.10.10.13; do
  sshpass -p azerty1234 ssh hci@$ip hostname
done
