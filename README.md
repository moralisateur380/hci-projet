# VIRT-07 - Micro-projet HCI (groupe 11)

Gautier Fouteret, Victor Tassart, Jacques-D'evaldo Tobossou

Stack : Ubuntu Server 24.04 LTS, KVM/QEMU + libvirt, GlusterFS (replica 3), Ansible, hcictl, bridge netplan.
HÃ´te de laboratoire : Proxmox VE (3 VM Ubuntu hci1/hci2/hci3). Proxmox n'est PAS la solution HCI livrÃ©e.
Travail Ã  distance : Twingate (voir la section dÃ©diÃ©e).

## Architecture

```text
 PC portable ---- mÃªme rÃ©seau, ou Twingate ----> pve (Proxmox VE, 192.168.20.206)
                                                   |
  vmbr0  ESGI LAB  192.168.20.0/24   Internet et accÃ¨s SSH / interface web (8006)
  vmbr1  privÃ©     10.10.10.0/24     cluster : SSH, Ansible, Gluster, migration (pve = .254)
  vmbr2  NAT       192.168.100.0/24  VM invitÃ©es (DHCP dnsmasq sur pve = .1)

  +-----------------+  +-----------------+  +-----------------+
  | hci1 (VM 100)   |  | hci2 (VM 101)   |  | hci3 (VM 102)   |
  | KVM + libvirt   |  | KVM + libvirt   |  | KVM + libvirt   |
  | glusterd        |  | glusterd        |  | glusterd        |
  | brique sdb 60Go |  | brique sdb 60Go |  | brique sdb 60Go |
  | br0 (VM invit.) |  | br0 (VM invit.) |  | br0 (VM invit.) |
  +--------+--------+  +--------+--------+  +--------+--------+
           |                    |                    |
           +--------- volume vmstore (replica 3) ----+
                montÃ© sur /var/lib/libvirt/images/hci
        (disques des VM, ISO cloud-init, XML, placement, drapeau HA)

  hcictl (CLI) : create, list, migrate (Ã  chaud), evacuate, failover, status
  Ansible (site.yml) : dÃ©ploie tout depuis hci1
```

SchÃ©ma Mermaid : `docs/architecture.md`.

## Arborescence

```text
hci-projet/
â”œâ”€â”€ README.md
â”œâ”€â”€ .gitignore
â”œâ”€â”€ setup.ps1                         (local, non versionnÃ© : rÃ©gÃ©nÃ¨re ce dÃ©pÃ´t)
â”œâ”€â”€ docs/
â”‚   â””â”€â”€ architecture.md               schÃ©ma Mermaid, rÃ©seau, machines
â”œâ”€â”€ hci-poc/                          projet Ansible (Ã  copier dans ~/hci-poc sur hci1)
â”‚   â”œâ”€â”€ ansible.cfg
â”‚   â”œâ”€â”€ inventory.ini
â”‚   â”œâ”€â”€ site.yml
â”‚   â”œâ”€â”€ group_vars/all.yml
â”‚   â”œâ”€â”€ files/
â”‚   â”‚   â”œâ”€â”€ hcictl                    CLI d'administration
â”‚   â”‚   â”œâ”€â”€ user-data.tpl             template cloud-init
â”‚   â”‚   â””â”€â”€ hci_id_ed25519(.pub)      clÃ© de cluster (gÃ©nÃ©rÃ©e, jamais versionnÃ©e)
â”‚   â””â”€â”€ templates/
â”‚       â”œâ”€â”€ netplan.yaml.j2
â”‚       â””â”€â”€ hcictl.conf.j2
â””â”€â”€ scripts/
    â”œâ”€â”€ 01-pve-create-hci-user.sh     (sur pve) crÃ©e/force l'utilisateur hci
    â”œâ”€â”€ 02-hci1-prepare.sh            (sur hci1) paquets + clÃ© de cluster
    â”œâ”€â”€ 03-hci1-deploy.sh             (sur hci1) lance le playbook
    â”œâ”€â”€ 04-verify.sh                  (sur hci1) vÃ©rifications
    â”œâ”€â”€ 05-demo.sh                    (sur hci1) dÃ©mo : convergence, migration, panne
    â””â”€â”€ 06-livrables.sh               (sur hci1) archive, sommes de contrÃ´le, preuves
```

## RÃ©seau

| Machine | PrivÃ© (vmbr1) | ESGI LAB (vmbr0) | VM invitÃ©es (vmbr2) |
|---|---|---|---|
| pve | 10.10.10.254 | 192.168.20.206 | 192.168.100.1 |
| hci1 | 10.10.10.11 (ens19) | DHCP (ens18) | br0 192.168.100.11 (ens20) |
| hci2 | 10.10.10.12 | DHCP | br0 192.168.100.12 |
| hci3 | 10.10.10.13 | DHCP | br0 192.168.100.13 |

Attention : dans cette installation, ens19 = privÃ©, ens18 = uplink ESGI LAB, ens20 = VM invitÃ©es.
VÃ©rifier avec `ip -br a` avant de lancer le playbook ; adapter `hci-poc/group_vars/all.yml` si besoin.

## Machines Proxmox

| ID | Nom | RÃ´le | RAM / disques |
|---|---|---|---|
| 100 | hci1 | nÅ“ud 1 (contrÃ´le Ansible) | 4 Go, sda 20 Go + sdb 60 Go |
| 101 | hci2 | nÅ“ud 2 | 4 Go, sda 20 Go + sdb 60 Go |
| 102 | hci3 | nÅ“ud 3 | 4 Go, sda 20 Go + sdb 60 Go |
| 103 | twingate-connector | accÃ¨s Ã  distance (Twingate) | **ne jamais arrÃªter ni supprimer** |

## Travail Ã  distance (Twingate)

Le travail Ã  distance se fait avec **Twingate** (accÃ¨s rÃ©seau Â« zero trust Â», rien n'est ouvert sur Internet).

- Un connecteur Twingate tourne sur pve : `103 (twingate-connector)`. Il donne accÃ¨s au rÃ©seau du labo.
- Sur le PC : installer le client Twingate, se connecter avec le compte du groupe, puis utiliser les mÃªmes adresses qu'au labo.
- Ressources Ã  autoriser dans la console Twingate : `192.168.20.206` (SSH 22 et Proxmox 8006) et `10.10.10.0/24` (SSH 22).
- Une fois connectÃ© :

```bash
ssh root@192.168.20.206                      # pve
ssh -J root@192.168.20.206 hci@10.10.10.11   # hci1 via pve en rebond
# interface web Proxmox : https://192.168.20.206:8006
```

- Ne jamais arrÃªter, supprimer ni restaurer la machine 103 : on perdrait l'accÃ¨s Ã  distance.

## Identifiants de laboratoire

- Utilisateurs `ubuntu` et `hci` : mot de passe `azerty1234` (laboratoire uniquement).
- VM invitÃ©es crÃ©Ã©es par hcictl : `ubuntu` / `ubuntu`.
- Ne pas publier ce dÃ©pÃ´t en public avec ces mots de passe.

## Mise en oeuvre

1. Copier le projet vers hci1 depuis le PC (PowerShell, via pve en rebond) :

   ```powershell
   scp -r -J root@192.168.20.206 .\hci-poc hci@10.10.10.11:~/
   scp -r -J root@192.168.20.206 .\scripts hci@10.10.10.11:~/
   ```

2. Sur pve : `bash 01-pve-create-hci-user.sh` (si `hci` n'existe pas ou mot de passe inconnu).
3. Sur hci1 (en `hci`) : `bash ~/scripts/02-hci1-prepare.sh` (gÃ©nÃ¨re la clÃ© de cluster si absente).
4. Sur hci1 : `bash ~/scripts/03-hci1-deploy.sh` (10 Ã  15 min).
5. Sur hci1 : `bash ~/scripts/04-verify.sh`, puis la dÃ©mo `05-demo.sh`.
6. Sur hci1 : `bash ~/scripts/06-livrables.sh` (archive, sommes de contrÃ´le, preuves).

Si `~/hci-poc` existe dÃ©jÃ  sur hci1 avec la clÃ© `files/hci_id_ed25519`, la conserver : ne pas la remplacer.
La clÃ© privÃ©e n'est jamais versionnÃ©e ni livrÃ©e (voir `.gitignore`).

## VÃ©rification et dÃ©monstration

```bash
bash ~/scripts/04-verify.sh                               # tout doit Ãªtre [OK]
NOPAUSE=1 bash ~/scripts/05-demo.sh | tee ~/demo.log      # dÃ©mo complÃ¨te avec une trace
bash ~/scripts/05-demo.sh                                 # dÃ©mo avec pauses (pour l'oral)
bash ~/scripts/06-livrables.sh                            # livrables dans ~/livrables
```

La dÃ©mo coupe `hci3` (VM Proxmox 102). Si le script ne peut pas le couper, le faire sur pve : `qm stop 102`,
puis `qm start 102` pour le rallumer. Ne jamais toucher Ã  la 103 (Twingate).

## Corrections par rapport au document d'origine

- Module `community.general.gluster_volume` absent des versions rÃ©centes : remplacÃ© par `gluster volume create ... force` et `gluster volume start` (idempotents).
- TÃ¢che ajoutÃ©e pour crÃ©er `/home/hci/.ssh` avant la copie de la clÃ© de cluster.
- `playbook_dir` utilisÃ© pour les chemins des fichiers.
- CapacitÃ© utile du volume : ~60 Go (replica 3 = capacitÃ© d'une brique).
- Fichiers rÃ©Ã©crits sans les caractÃ¨res perdus du document (`$`, guillemets, tabulations).

## Relances

Sur hci1, dans `~/hci-poc` :

```bash
# AprÃ¨s le 1er passage : rejouer tout le playbook (clÃ© de cluster, sudo sans mot de passe)
ansible-playbook site.yml --private-key files/hci_id_ed25519

# Rejouer seulement une partie (tags : base, gluster, pool)
ansible-playbook site.yml --private-key files/hci_id_ed25519 --tags base
ansible-playbook site.yml --private-key files/hci_id_ed25519 --tags gluster,pool
```

## DÃ©pannage rapide

- `/dev/kvm` absent : nested non actif sur pve, ou VM pas en `--cpu host`.
- `cache=none : Invalid argument` : mettre `DISK_CACHE="writethrough"` et `MIGRATE_OPTS="--unsafe"` dans `/etc/hcictl.conf` (sur les 3 nÅ“uds).
- `Unknown OS name ubuntu24.04` : remplacer par `--os-variant detect=on,require=off` dans hcictl.
- Droits libvirt non pris en compte : se dÃ©connecter puis se reconnecter en `hci`.
- AccÃ¨s Ã  distance perdu : vÃ©rifier que la machine 103 (twingate-connector) tourne sur pve.

## Limites

Failover = redÃ©marrage (pas de continuitÃ©), mots de passe de laboratoire, performances limitÃ©es par FUSE Gluster
et la virtualisation imbriquÃ©e, sudo sans mot de passe rÃ©servÃ© au POC, 3 nÅ“uds sur une seule machine physique.
