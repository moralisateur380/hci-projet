# VIRT-07 - Micro-projet HCI (groupe 11)

Gautier Fouteret, Victor Tassart, Jacques-d'Evaldo Tobossou

Stack : Ubuntu Server 24.04 LTS, KVM/QEMU + libvirt, GlusterFS (replica 3), Ansible, hcictl, bridge netplan.
Hôte de laboratoire : Proxmox VE (3 VM Ubuntu hci1/hci2/hci3). Proxmox n'est PAS la solution HCI livrée.
Travail à distance : Twingate (voir la section dédiée).

## Architecture

```text
 PC portable ---- même réseau, ou Twingate ----> pve (Proxmox VE, 192.168.20.206)
                                                   |
  vmbr0  ESGI LAB  192.168.20.0/24   Internet et accès SSH / interface web (8006)
  vmbr1  privé     10.10.10.0/24     cluster : SSH, Ansible, Gluster, migration (pve = .254)
  vmbr2  NAT       192.168.100.0/24  VM invitées (DHCP dnsmasq sur pve = .1)

  +-----------------+  +-----------------+  +-----------------+
  | hci1 (VM 100)   |  | hci2 (VM 101)   |  | hci3 (VM 102)   |
  | KVM + libvirt   |  | KVM + libvirt   |  | KVM + libvirt   |
  | glusterd        |  | glusterd        |  | glusterd        |
  | brique sdb 60Go |  | brique sdb 60Go |  | brique sdb 60Go |
  | br0 (VM invit.) |  | br0 (VM invit.) |  | br0 (VM invit.) |
  +--------+--------+  +--------+--------+  +--------+--------+
           |                    |                    |
           +--------- volume vmstore (replica 3) ----+
                monté sur /var/lib/libvirt/images/hci
        (disques des VM, ISO cloud-init, XML, placement, drapeau HA)

  hcictl (CLI) : create, list, migrate (à chaud), evacuate, failover, status
  Ansible (site.yml) : déploie tout depuis hci1
```

Schéma Mermaid : `docs/architecture.md`.

## Arborescence

```text
hci-projet/
├── README.md
├── .gitignore
├── setup.ps1                         (local, non versionné : régénère ce dépôt)
├── docs/
│   └── architecture.md               schéma Mermaid, réseau, machines
├── hci-poc/                          projet Ansible (à copier dans ~/hci-poc sur hci1)
│   ├── ansible.cfg
│   ├── inventory.ini
│   ├── site.yml
│   ├── group_vars/all.yml
│   ├── files/
│   │   ├── hcictl                    CLI d'administration
│   │   ├── user-data.tpl             template cloud-init
│   │   └── hci_id_ed25519(.pub)      clé de cluster (générée, jamais versionnée)
│   └── templates/
│       ├── netplan.yaml.j2
│       └── hcictl.conf.j2
└── scripts/
    ├── 01-pve-create-hci-user.sh     (sur pve) crée/force l'utilisateur hci
    ├── 02-hci1-prepare.sh            (sur hci1) paquets + clé de cluster
    ├── 03-hci1-deploy.sh             (sur hci1) lance le playbook
    ├── 04-verify.sh                  (sur hci1) vérifications
    ├── 05-demo.sh                    (sur hci1) démo : convergence, migration, panne
    └── 06-livrables.sh               (sur hci1) archive, sommes de contrôle, preuves
```

## Réseau

| Machine | Privé (vmbr1) | ESGI LAB (vmbr0) | VM invitées (vmbr2) |
|---|---|---|---|
| pve | 10.10.10.254 | 192.168.20.206 | 192.168.100.1 |
| hci1 | 10.10.10.11 (ens19) | DHCP (ens18) | br0 192.168.100.11 (ens20) |
| hci2 | 10.10.10.12 | DHCP | br0 192.168.100.12 |
| hci3 | 10.10.10.13 | DHCP | br0 192.168.100.13 |

Attention : dans cette installation, ens19 = privé, ens18 = uplink ESGI LAB, ens20 = VM invitées.
Vérifier avec `ip -br a` avant de lancer le playbook ; adapter `hci-poc/group_vars/all.yml` si besoin.

## Machines Proxmox

| ID | Nom | Rôle | RAM / disques |
|---|---|---|---|
| 100 | hci1 | nœud 1 (contrôle Ansible) | 4 Go, sda 20 Go + sdb 60 Go |
| 101 | hci2 | nœud 2 | 4 Go, sda 20 Go + sdb 60 Go |
| 102 | hci3 | nœud 3 | 4 Go, sda 20 Go + sdb 60 Go |
| 103 | twingate-connector | accès à distance (Twingate) | **ne jamais arrêter ni supprimer** |

## Travail à distance (Twingate)

Le travail à distance se fait avec **Twingate** (accès réseau « zero trust », rien n'est ouvert sur Internet).

- Un connecteur Twingate tourne sur pve : `103 (twingate-connector)`. Il donne accès au réseau du labo.
- Sur le PC : installer le client Twingate, se connecter avec le compte du groupe, puis utiliser les mêmes adresses qu'au labo.
- Ressources à autoriser dans la console Twingate : `192.168.20.206` (SSH 22 et Proxmox 8006) et `10.10.10.0/24` (SSH 22).
- Une fois connecté :

```bash
ssh root@192.168.20.206                      # pve
ssh -J root@192.168.20.206 hci@10.10.10.11   # hci1 via pve en rebond
# interface web Proxmox : https://192.168.20.206:8006
```

- Ne jamais arrêter, supprimer ni restaurer la machine 103 : on perdrait l'accès à distance.

## Identifiants de laboratoire

- Utilisateurs `ubuntu` et `hci` : mot de passe `azerty1234` (laboratoire uniquement).
- VM invitées créées par hcictl : `ubuntu` / `ubuntu`.
- Ne pas publier ce dépôt en public avec ces mots de passe.

## Mise en œuvre

1. Copier le projet vers hci1 depuis le PC (PowerShell, via pve en rebond) :

   ```powershell
   scp -r -J root@192.168.20.206 .\hci-poc hci@10.10.10.11:~/
   scp -r -J root@192.168.20.206 .\scripts hci@10.10.10.11:~/
   ```

2. Sur pve : `bash 01-pve-create-hci-user.sh` (si `hci` n'existe pas ou mot de passe inconnu).
3. Sur hci1 (en `hci`) : `bash ~/scripts/02-hci1-prepare.sh` (génère la clé de cluster si absente).
4. Sur hci1 : `bash ~/scripts/03-hci1-deploy.sh` (10 à 15 min).
5. Sur hci1 : `bash ~/scripts/04-verify.sh`, puis la démo `05-demo.sh`.
6. Sur hci1 : `bash ~/scripts/06-livrables.sh` (archive, sommes de contrôle, preuves).

Si `~/hci-poc` existe déjà sur hci1 avec la clé `files/hci_id_ed25519`, la conserver : ne pas la remplacer.
La clé privée n'est jamais versionnée ni livrée (voir `.gitignore`).

## Vérification et démonstration

```bash
bash ~/scripts/04-verify.sh                               # tout doit être [OK]
NOPAUSE=1 bash ~/scripts/05-demo.sh | tee ~/demo.log      # démo complète avec une trace
bash ~/scripts/05-demo.sh                                 # démo avec pauses (pour l'oral)
bash ~/scripts/06-livrables.sh                            # livrables dans ~/livrables
```

La démo coupe `hci3` (VM Proxmox 102). Si le script ne peut pas le couper, le faire sur pve : `qm stop 102`,
puis `qm start 102` pour le rallumer. Ne jamais toucher à la 103 (Twingate).

## Corrections par rapport au document d'origine

- Module `community.general.gluster_volume` absent des versions récentes : remplacé par `gluster volume create ... force` et `gluster volume start` (idempotents).
- Tâche ajoutée pour créer `/home/hci/.ssh` avant la copie de la clé de cluster.
- `playbook_dir` utilisé pour les chemins des fichiers.
- Capacité utile du volume : ~60 Go (replica 3 = capacité d'une brique).
- Fichiers réécrits sans les caractères perdus du document (`$`, guillemets, tabulations).

## Relances

Sur hci1, dans `~/hci-poc` :

```bash
# Après le 1er passage : rejouer tout le playbook (clé de cluster, sudo sans mot de passe)
ansible-playbook site.yml --private-key files/hci_id_ed25519

# Rejouer seulement une partie (tags : base, gluster, pool)
ansible-playbook site.yml --private-key files/hci_id_ed25519 --tags base
ansible-playbook site.yml --private-key files/hci_id_ed25519 --tags gluster,pool
```

## Dépannage rapide

- `/dev/kvm` absent : nested non actif sur pve, ou VM pas en `--cpu host`.
- `cache=none : Invalid argument` : mettre `DISK_CACHE="writethrough"` et `MIGRATE_OPTS="--unsafe"` dans `/etc/hcictl.conf` (sur les 3 nœuds).
- `Unknown OS name ubuntu24.04` : remplacer par `--os-variant detect=on,require=off` dans hcictl.
- Droits libvirt non pris en compte : se déconnecter puis se reconnecter en `hci`.
- Accès à distance perdu : vérifier que la machine 103 (twingate-connector) tourne sur pve.

## Limites

Failover = redémarrage (pas de continuité), mots de passe de laboratoire, performances limitées par FUSE Gluster
et la virtualisation imbriquée, sudo sans mot de passe réservé au POC, 3 nœuds sur une seule machine physique.
