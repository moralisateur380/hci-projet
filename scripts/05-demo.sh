#!/usr/bin/env bash
# 05-demo.sh : dÃ©monstration de la convergence, de la migration et de la panne d'un nÅ“ud.
# Ã€ lancer sur hci1, en utilisateur hci.
#   Avec pauses :       bash ~/scripts/05-demo.sh
#   Sans pause + trace : NOPAUSE=1 bash ~/scripts/05-demo.sh | tee demo.log
set -uo pipefail

[ -f /etc/hcictl.conf ] && . /etc/hcictl.conf
NODES=${NODES:-"hci1 hci2 hci3"}
POOL=${POOL:-/var/lib/libvirt/images/hci}
VOL=vmstore
BRICK=/data/brick1/vmstore
PLACE=$POOL/placement
VICTIM=hci3                       # nÅ“ud qu'on coupe pendant le test de panne (pas hci1 : on est dessus)
# NumÃ©ro de la VM dans Proxmox : hci1=100, hci2=101, hci3=102 (103 = twingate-connector : NE PAS Y TOUCHER)
VICTIM_ID=${VICTIM_ID:-$((99 + ${VICTIM#hci}))}

step()  { printf '\n=== %s ===\n' "$*"; }
run()   { printf '$ %s\n' "$*"; eval "$*"; }
pause() { [ "${NOPAUSE:-0}" = 1 ] && return 0; read -r -p "--- EntrÃ©e pour continuer ---" _; }

node_ssh() { local n=$1; shift; ssh -o BatchMode=yes -o ConnectTimeout=5 "hci@$n" "$@"; }
vm_ssh()   { local ip=$1; shift; ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "ubuntu@$ip" "$@"; }
vm_node()  { hcictl list | awk -v v="$1" '$2==v {print $1; exit}'; }

heal_pending() {
  sudo gluster volume heal "$VOL" info summary 2>/dev/null | awk '/in heal pending|in split-brain/ {s+=$NF} END {print s+0}'
}
bricks_online() {
  sudo gluster volume status "$VOL" 2>/dev/null | awk '/^Brick/ && $(NF-1)=="Y" {c++} END {print c+0}'
}

wait_ip() {   # wait_ip NOM : affiche l'IP de la VM (5 min max)
  local i ip
  for i in $(seq 1 60); do
    ip=$(hcictl ip "$1" 2>/dev/null | awk '/ipv4/ && $4 !~ /^127\./ {sub("/.*", "", $4); print $4; exit}')
    if [ -n "$ip" ]; then echo "$ip"; return 0; fi
    sleep 5
  done
  return 1
}
wait_ssh() {  # wait_ssh IP : attend que la VM accepte SSH (2 min max)
  local i
  for i in $(seq 1 24); do vm_ssh "$1" true >/dev/null 2>&1 && return 0; sleep 5; done
  return 1
}

declare -A IP

# ---------------------------------------------------------------------------
step "1. Trois VM, une par nÅ“ud, sur le volume rÃ©pliquÃ©"
for i in 1 2 3; do
  if [ -z "$(vm_node web$i)" ]; then run "hcictl create web$i --node hci$i"; else echo "web$i existe dÃ©jÃ "; fi
done
run "hcictl list"
for i in 1 2 3; do
  echo "Attente de l'IP de web$i (cloud-init : 1 Ã  2 minutes)..."
  IP[web$i]=$(wait_ip "web$i") || { echo "ECHEC : web$i n'a pas d'IP. Voir : hcictl console web$i"; exit 1; }
  wait_ssh "${IP[web$i]}" || { echo "ECHEC : SSH impossible vers web$i (${IP[web$i]})"; exit 1; }
  echo "web$i : ${IP[web$i]}"
done
pause

# ---------------------------------------------------------------------------
step "2. Preuve : les disques sont distribuÃ©s sur les 3 nÅ“uds"
run "ls -lh $POOL/disks"
for n in $NODES; do
  echo "-- $n : nombre de disques vus dans le volume, puis copie physique sur sa brique"
  node_ssh "$n" "ls $POOL/disks | wc -l; sudo ls -lh $BRICK/disks"
done
run "sudo gluster volume heal $VOL info summary | grep -E 'Brick|heal pending'"
pause

# ---------------------------------------------------------------------------
step "3. Charge rÃ©partie : CPU et Ã©critures disque dans les 3 VM"
for i in 1 2 3; do
  vm_ssh "${IP[web$i]}" '(nohup timeout 60 yes >/dev/null 2>&1 </dev/null &)'
done
run "hcictl status"
for i in 1 2 3; do
  echo "-- web$i sur $(vm_node web$i) : Ã©criture de 300 Mo sur le disque distribuÃ©"
  vm_ssh "${IP[web$i]}" 'dd if=/dev/zero of=/tmp/t bs=1M count=300 oflag=direct conv=fsync 2>&1 | tail -1; rm -f /tmp/t'
done
pause

# ---------------------------------------------------------------------------
step "4. Migration Ã  chaud de web1 (la VM ne redÃ©marre pas)"
SRC=$(vm_node web1)
DST=hci2
[ "$SRC" = "$DST" ] && DST=hci3
before=$(vm_ssh "${IP[web1]}" 'uptime -s')
echo "web1 : $SRC -> $DST ; dÃ©marrÃ©e le $before"
ping -i 0.2 -c 250 "${IP[web1]}" > /tmp/ping-demo.txt 2>&1 &
PING_PID=$!
run "hcictl migrate web1 $DST" || echo "La migration a Ã©chouÃ© : voir le dÃ©pannage (cache=none / --unsafe)."
wait "$PING_PID" 2>/dev/null
echo "RÃ©sultat du ping pendant la migration :"
tail -2 /tmp/ping-demo.txt
run "hcictl list"
after=$(vm_ssh "${IP[web1]}" 'uptime -s' 2>/dev/null || echo "?")
if [ "$before" = "$after" ]; then echo "DÃ©marrage de la VM inchangÃ© ($after) : elle n'a pas redÃ©marrÃ©."; else echo "ATTENTION : dÃ©marrage diffÃ©rent ($after)"; fi
pause

# ---------------------------------------------------------------------------
step "5. Maintenance : on vide hci2 (ses VM migrent Ã  chaud)"
run "hcictl evacuate hci2"
run "hcictl list"
if [ "$(vm_node web3)" != "$VICTIM" ]; then
  echo "On remet web3 sur $VICTIM pour prÃ©parer le test de panne."
  run "hcictl migrate web3 $VICTIM"
fi
pause

# ---------------------------------------------------------------------------
step "6. Panne brutale de $VICTIM : les VM HA redÃ©marrent ailleurs"
ON_VICTIM=$(hcictl list | awk -v n="$VICTIM" '$1==n && $3=="running" {print $2}')
echo "VM qui tournent sur $VICTIM : $ON_VICTIM"
echo "On coupe $VICTIM sans arrÃªt propre."
pause
T0=$(date +%s)
node_ssh "$VICTIM" 'sudo systemctl poweroff --force --force' >/dev/null 2>&1 || true
for i in $(seq 1 30); do node_ssh "$VICTIM" true >/dev/null 2>&1 || break; sleep 2; done
if node_ssh "$VICTIM" true >/dev/null 2>&1; then
  echo "$VICTIM rÃ©pond encore. Coupez-le depuis pve :  qm stop $VICTIM_ID"
  for i in $(seq 1 60); do node_ssh "$VICTIM" true >/dev/null 2>&1 || break; sleep 2; done
fi
if node_ssh "$VICTIM" true >/dev/null 2>&1; then echo "ECHEC : $VICTIM est toujours en ligne."; exit 1; fi
echo "$VICTIM est hors ligne ($(( $(date +%s) - T0 )) s)."

run "hcictl failover $VICTIM"
run "hcictl list"
for vm in $ON_VICTIM; do
  ip=${IP[$vm]:-}
  [ -n "$ip" ] || continue
  until ping -c1 -W1 "$ip" >/dev/null 2>&1; do
    sleep 2
    if [ $(( $(date +%s) - T0 )) -gt 300 ]; then echo "$vm injoignable aprÃ¨s 5 min"; break; fi
  done
  echo "$vm : joignable $(( $(date +%s) - T0 )) s aprÃ¨s la panne, maintenant sur $(vm_node "$vm")"
done
echo "Le stockage reste disponible avec 2 nÅ“uds sur 3 (quorum) :"
run "sudo gluster volume status $VOL | grep -E '^Brick'"
run "ls $POOL/disks"
pause

# ---------------------------------------------------------------------------
step "7. Retour du nÅ“ud et rÃ©paration automatique"
echo "Sur pve, rallumez le nÅ“ud :  qm start $VICTIM_ID"
echo "Attente du retour de $VICTIM (5 min max)..."
for i in $(seq 1 100); do node_ssh "$VICTIM" true >/dev/null 2>&1 && break; sleep 3; done
node_ssh "$VICTIM" true >/dev/null 2>&1 || { echo "$VICTIM ne revient pas."; exit 1; }
node_ssh "$VICTIM" "mountpoint -q $POOL || sudo mount -a" >/dev/null 2>&1
echo "RÃ©paration Gluster (heal) :"
for i in $(seq 1 60); do
  b=$(bricks_online); p=$(heal_pending)
  echo "  briques en ligne : $b/3 ; entrÃ©es Ã  rÃ©parer : $p"
  if [ "$b" -eq 3 ] && [ "$p" -eq 0 ]; then break; fi
  sleep 5
done

echo "Nettoyage des dÃ©finitions obsolÃ¨tes sur $VICTIM :"
URI="qemu+ssh://hci@${VICTIM}/system?no_tty=1"
for f in "$PLACE"/*; do
  [ -e "$f" ] || continue
  name=$(basename "$f")
  [ "$(cat "$f")" = "$VICTIM" ] && continue
  if virsh -c "$URI" dominfo "$name" >/dev/null 2>&1; then
    virsh -c "$URI" undefine "$name" --nvram >/dev/null 2>&1 || virsh -c "$URI" undefine "$name" >/dev/null 2>&1
    echo "  dÃ©finition obsolÃ¨te supprimÃ©e : $name"
  fi
done
run "hcictl list"
run "hcictl status"

# ---------------------------------------------------------------------------
if [ "${NOPAUSE:-0}" != 1 ]; then
  read -r -p "Supprimer les VM de dÃ©mo web1, web2, web3 ? [o/N] " rep
  if [ "$rep" = o ]; then for i in 1 2 3; do hcictl delete "web$i"; done; fi
fi
echo; echo "DÃ©mo terminÃ©e."
