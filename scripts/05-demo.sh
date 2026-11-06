#!/usr/bin/env bash
# DÃ©mo de convergence, sur hci1. Les IP des VM sont Ã  relever avec : hcictl ip web1
hcictl create web1 --node hci1
hcictl create web2 --node hci2
hcictl create web3 --node hci3
hcictl list
echo "Attendre ~1 min puis : hcictl ip web1"
echo "Migration Ã  chaud : hcictl migrate web1 hci2"
echo "Maintenance       : hcictl evacuate hci2"
echo "Panne (sur pve)   : qm stop 102 ; puis sur hci1 : hcictl failover hci3"
