#!/usr/bin/env bash
# 04-verify.sh : vÃ©rifications aprÃ¨s le dÃ©ploiement Ansible.
# Ã€ lancer sur hci1, en utilisateur hci :  bash ~/scripts/04-verify.sh
set -uo pipefail

[ -f /etc/hcictl.conf ] && . /etc/hcictl.conf
NODES=${NODES:-"hci1 hci2 hci3"}
POOL=${POOL:-/var/lib/libvirt/images/hci}
VOL=vmstore
BRICK=/data/brick1
FAIL=0

ok()  { printf '  [OK]     %s\n' "$*"; }
ko()  { printf '  [ECHEC]  %s\n' "$*"; FAIL=$((FAIL + 1)); }
chk() { local msg=$1; shift; if "$@" >/dev/null 2>&1; then ok "$msg"; else ko "$msg"; fi; }
rsh() { local n=$1; shift; ssh -o BatchMode=yes -o ConnectTimeout=5 "hci@$n" "$@"; }

echo "== 0. Utilisateur"
chk "connectÃ© en hci" test "$(whoami)" = hci
chk "hci est dans le groupe libvirt (sinon : exit puis reconnexion)" sh -c 'id -nG | grep -qw libvirt'

echo "== 1. NÅ“uds"
for n in $NODES; do
  echo " $n"
  chk "SSH par la clÃ© de cluster" rsh "$n" true
  chk "/dev/kvm prÃ©sent" rsh "$n" test -e /dev/kvm
  chk "libvirtd actif" rsh "$n" systemctl is-active --quiet libvirtd
  chk "glusterd actif" rsh "$n" systemctl is-active --quiet glusterd
  chk "br0 en 192.168.100.x" rsh "$n" "ip -br addr show br0 | grep -q 192.168.100."
  chk "brique montÃ©e ($BRICK)" rsh "$n" mountpoint -q "$BRICK"
  chk "volume montÃ© ($POOL)" rsh "$n" mountpoint -q "$POOL"
done

echo "== 2. GlusterFS"
peers=$(sudo gluster peer status 2>/dev/null | grep -c 'Peer in Cluster (Connected)')
if [ "$peers" -eq 2 ]; then ok "2 pairs connectÃ©s"; else ko "pairs connectÃ©s : $peers (attendu : 2)"; fi

info=$(sudo gluster volume info "$VOL" 2>/dev/null)
if echo "$info" | grep -q 'Status: Started'; then ok "volume $VOL dÃ©marrÃ©"; else ko "volume $VOL non dÃ©marrÃ©"; fi
if echo "$info" | grep -q 'Number of Bricks: 1 x 3 = 3'; then ok "replica 3 (3 briques)"; else ko "le volume n'est pas en replica 3"; fi

online=$(sudo gluster volume status "$VOL" 2>/dev/null | awk '/^Brick/ && $(NF-1)=="Y" {c++} END {print c+0}')
if [ "$online" -eq 3 ]; then ok "3 briques en ligne"; else ko "briques en ligne : $online (attendu : 3)"; fi

pending=$(sudo gluster volume heal "$VOL" info summary 2>/dev/null | awk '/in heal pending|in split-brain/ {s+=$NF} END {print s+0}')
if [ "$pending" -eq 0 ]; then ok "rien Ã  rÃ©parer (heal et split-brain Ã  0)"; else ko "$pending entrÃ©e(s) Ã  rÃ©parer"; fi

echo "== 3. Volume partagÃ©"
chk "image de base prÃ©sente" test -f "$POOL/base/noble-server-cloudimg-amd64.img"
t="$POOL/.verify-$$"
if echo ok > "$t" 2>/dev/null; then
  for n in $NODES; do chk "fichier Ã©crit sur hci1 visible depuis $n" rsh "$n" grep -qx ok "$t"; done
else
  ko "Ã©criture impossible dans $POOL (groupe libvirt pas encore pris en compte ?)"
fi
rm -f "$t"
chk "Ã©criture O_DIRECT possible (nÃ©cessaire pour cache=none)" dd if=/dev/zero of="$POOL/.odirect-$$" bs=4k count=1 oflag=direct
rm -f "$POOL/.odirect-$$"

echo "== 4. Ã‰tat vu par hcictl"
hcictl status

echo
if [ "$FAIL" -eq 0 ]; then
  echo "TOUT EST OK : vous pouvez lancer la dÃ©mo (bash ~/scripts/05-demo.sh)."
else
  echo "$FAIL contrÃ´le(s) en Ã©chec."
  echo "Si seul O_DIRECT Ã©choue, ajouter sur les 3 nÅ“uds dans /etc/hcictl.conf :"
  echo '  DISK_CACHE="writethrough"'
  echo '  MIGRATE_OPTS="--unsafe"'
  exit 1
fi
