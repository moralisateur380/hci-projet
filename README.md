# VIRT-07 - Micro-projet HCI (groupe 11)

Gautier Fouteret, Victor Tassart, Jacques-D'evaldo Tobossou

Stack : Ubuntu Server 24.04 LTS, KVM/QEMU + libvirt, GlusterFS (replica 3), Ansible, hcictl, bridge netplan.
Hôte de laboratoire : Proxmox VE (3 VM Ubuntu hci1/hci2/hci3). Proxmox n'est PAS la solution HCI livrée.

## Arborescence

```text
hci-projet/
├── README.md
├── hci-poc/                          projet Ansible (à copier dans ~/hci-poc sur hci1)
│   ├── ansible.cfg
│   ├── inventory.ini
│   ├── site.yml
│   ├── group_vars/all.yml
│   ├── files/
│   │   ├── hcictl                    CLI d'administration
│   │   └── user-data.tpl             template cloud-init
│   └── templates/
│       ├── netplan.yaml.j2
│       └── hcictl.conf.j2
└── scripts/
    ├── 01-pve-create-hci-user.sh     (sur pve) crée/force l'utilisateur hci
    ├── 02-hci1-prepare.sh            (sur hci1) paquets + clé de cluster
    ├── 03-hci1-deploy.sh             (sur hci1) lance le playbook
    ├── 04-verify.sh                  (sur hci1) vérifications
    └── 05-demo.sh                    (sur hci1) démo convergence
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

## Identifiants de laboratoire

- Utilisateurs `ubuntu` et `hci` : mot de passe `azerty1234` (laboratoire uniquement).
- VM invitées créées par hcictl : `ubuntu` / `ubuntu`.

## Mise en oeuvre

1. Copier le projet vers hci1 depuis le PC (PowerShell, via pve en rebond) :

   ```powershell
   scp -r -J root@192.168.20.206 .\hci-poc hci@10.10.10.11:~/
   scp -r -J root@192.168.20.206 .\scripts hci@10.10.10.11:~/
   ```

2. Sur pve : `bash 01-pve-create-hci-user.sh` (si `hci` n'existe pas ou mot de passe inconnu).
3. Sur hci1 (en `hci`) : `bash ~/scripts/02-hci1-prepare.sh` (génère la clé de cluster si absente).
4. Sur hci1 : `bash ~/scripts/03-hci1-deploy.sh` (10 à 15 min).
5. Sur hci1 : `bash ~/scripts/04-verify.sh`, puis la démo `05-demo.sh`.

Si `~/hci-poc` existe déjà sur hci1 avec la clé `files/hci_id_ed25519`, la conserver : ne pas la remplacer.
La clé privée n'est jamais versionnée ni livrée (voir `.gitignore`).

## Corrections par rapport au document d'origine

- Module `community.general.gluster_volume` absent des versions récentes : remplacé par `gluster volume create ... force` et `gluster volume start` (idempotents).
- Tâche ajoutée pour créer `/home/hci/.ssh` avant la copie de la clé de cluster.
- `playbook_dir` utilisé pour les chemins des fichiers.
- Capacité utile du volume : ~60 Go (replica 3 = capacité d'une brique).
- Fichiers réécrits sans les caractères perdus du document (`$`, guillemets, tabulations).

## Relances

Sur hci1, dans `~/hci-poc` :

```bash
# Après le 1er passage : rejouer tout le playbook
ansible-playbook site.yml --private-key files/hci_id_ed25519

# Rejouer seulement une partie (tags : base, gluster, pool)
ansible-playbook site.yml --private-key files/hci_id_ed25519 --tags base
ansible-playbook site.yml --private-key files/hci_id_ed25519 --tags gluster,pool
```

## Dépannage rapide

- `/dev/kvm` absent : nested non actif sur pve, ou VM pas en `--cpu host`.
- `cache=none : Invalid argument` : mettre `DISK_CACHE="writethrough"` et `MIGRATE_OPTS="--unsafe"` dans `/etc/hcictl.conf`.
- `Unknown OS name ubuntu24.04` : remplacer par `--os-variant detect=on,require=off` dans hcictl.
- Droits libvirt non pris en compte : se déconnecter puis se reconnecter en `hci`.

## Limites

Failover = redémarrage (pas de continuité), mots de passe de laboratoire, performances limitées par FUSE Gluster
et la virtualisation imbriquée, sudo sans mot de passe réservé au POC, 3 nœuds sur une seule machine physique.