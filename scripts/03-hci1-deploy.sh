#!/usr/bin/env bash
# À lancer sur hci1 en tant que hci. Premier passage : mot de passe ; relances : clé de cluster.
set -euo pipefail
cd ~/hci-poc
PW='azerty1234'
ls files/
ansible hci -m ping -e ansible_password=$PW
ansible-playbook site.yml --syntax-check
ansible-playbook site.yml -e ansible_password=$PW -e ansible_become_password=$PW
