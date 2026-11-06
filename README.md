# VIRT-07 - Micro-projet HCI (groupe 11)

Gautier Fouteret, Victor Tassart, Jacques-D'evaldo Tobossou

Stack : Ubuntu Server 24.04 LTS, KVM/QEMU + libvirt, GlusterFS (replica 3), Ansible, hcictl, bridge netplan.
HÃ´te de laboratoire : Proxmox VE (3 VM Ubuntu hci1/hci2/hci3). Proxmox n'est PAS la solution HCI livrÃ©e.

## Arborescence
## RÃ©seau

| Machine | PrivÃ© (vmbr1) | ESGI LAB (vmbr0) | VM invitÃ©es (vmbr2) |
|---|---|---|---|
| pve | 10.10.10.254 | 192.168.20.206 | 192.168.100.1 |
| hci1 | 10.10.10.11 (ens19) | DHCP (ens18) | br0 192.168.100.11 (ens20) |
| hci2 | 10.10.10.12 | DHCP | br0 192.168.100.12 |
| hci3 | 10.10.10.13 | DHCP | br0 192.168.100.13 |

Attention : dans cette installation, ens19 = privÃ©, ens18 = uplink ESGI LAB, ens20 = VM invitÃ©es.
VÃ©rifier avec `ip -br a` avant de lancer le playbook ; adapter `hci-poc/group_vars/all.yml` si besoin.

## Identifiants de laboratoire

- Utilisateurs `ubuntu` et `hci` : mot de passe `azerty1234` (laboratoire uniquement).
- VM invitÃ©es crÃ©Ã©es par hcictl : `ubuntu` / `ubuntu`.

## Mise en oeuvre

1. Copier le projet vers hci1 depuis le PC (PowerShell, via pve en rebond) :
2. Sur pve : `bash 01-pve-create-hci-user.sh` (si `hci` n'existe pas ou mot de passe inconnu).
3. Sur hci1 (en `hci`) : `bash ~/scripts/02-hci1-prepare.sh` (gÃ©nÃ¨re la clÃ© de cluster si absente).
4. Sur hci1 : `bash ~/scripts/03-hci1-deploy.sh` (10 Ã  15 min).
5. Sur hci1 : `bash ~/scripts/04-verify.sh`, puis la dÃ©mo `05-demo.sh`.

Si `~/hci-poc` existe dÃ©jÃ  sur hci1 avec la clÃ© `files/hci_id_ed25519`, la conserver : ne pas la remplacer.
La clÃ© privÃ©e n'est jamais versionnÃ©e ni livrÃ©e (voir `.gitignore`).

## Corrections par rapport au document d'origine

- Module `community.general.gluster_volume` absent des versions rÃ©centes : remplacÃ© par `gluster volume create ... force` et `gluster volume start` (idempotents).
- TÃ¢che ajoutÃ©e pour crÃ©er `/home/hci/.ssh` avant la copie de la clÃ© de cluster.
- `playbook_dir` utilisÃ© pour les chemins des fichiers.
- CapacitÃ© utile du volume : ~60 Go (replica 3 = capacitÃ© d'une brique).
- Fichiers rÃ©Ã©crits sans les caractÃ¨res perdus du document (`$`, guillemets, tabulations).

## Relances
## DÃ©pannage rapide

- `/dev/kvm` absent : nested non actif sur pve, ou VM pas en `--cpu host`.
- `cache=none : Invalid argument` : mettre `DISK_CACHE="writethrough"` et `MIGRATE_OPTS="--unsafe"` dans `/etc/hcictl.conf`.
- `Unknown OS name ubuntu24.04` : remplacer par `--os-variant detect=on,require=off` dans hcictl.
- Droits libvirt non pris en compte : se dÃ©connecter puis se reconnecter en `hci`.

## Limites

Failover = redÃ©marrage (pas de continuitÃ©), mots de passe de laboratoire, performances limitÃ©es par FUSE Gluster
et la virtualisation imbriquÃ©e, sudo sans mot de passe rÃ©servÃ© au POC, 3 nÅ“uds sur une seule machine physique.
