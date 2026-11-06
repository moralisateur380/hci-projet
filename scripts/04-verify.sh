#!/usr/bin/env bash
# A lancer sur hci1 en tant que hci (se reconnecter aprÃ¨s le playbook pour les groupes libvirt/kvm).
ip -br a show br0
sudo gluster peer status
sudo gluster volume status vmstore
df -h /var/lib/libvirt/images/hci
ls /var/lib/libvirt/images/hci/base
hcictl status
