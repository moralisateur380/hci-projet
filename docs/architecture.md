# Architecture

```mermaid
flowchart TB
  PC["PC portable"] -->|"mÃªme rÃ©seau ou Twingate"| PVE
  subgraph PVE["pve : Proxmox VE (192.168.20.206)"]
    direction TB
    H1["hci1 (VM 100)"]
    H2["hci2 (VM 101)"]
    H3["hci3 (VM 102)"]
    TW["twingate-connector (103)"]
  end
  H1 --- G[("GlusterFS vmstore (replica 3)")]
  H2 --- G
  H3 --- G
```

## RÃ©seaux

| Pont Proxmox | RÃ©seau | RÃ´le |
|---|---|---|
| vmbr0 | 192.168.20.0/24 (ESGI LAB) | Internet, accÃ¨s SSH et interface web de pve |
| vmbr1 | 10.10.10.0/24 (privÃ©, isolÃ©) | Cluster : SSH, Ansible, Gluster, migration |
| vmbr2 | 192.168.100.0/24 (NAT + DHCP) | VM invitÃ©es, vues par les nÅ“uds via br0 |

## Briques

| Brique | Choix | RÃ´le |
|---|---|---|
| OS | Ubuntu Server 24.04 LTS | Base des 3 nÅ“uds |
| Hyperviseur | KVM/QEMU + libvirt | ExÃ©cution des VM |
| Stockage distribuÃ© | GlusterFS, volume vmstore replica 3 | Disques des VM copiÃ©s sur 3 nÅ“uds |
| DÃ©ploiement | Ansible | Cluster reproductible depuis hci1 |
| Management | hcictl (bash) | CrÃ©ation, migration, Ã©vacuation, failover |
| RÃ©seau | Bridge br0 (netplan) | RÃ©seau des VM invitÃ©es |
| AccÃ¨s Ã  distance | Twingate | Travail hors du labo |
