#!/usr/bin/env bash
# 06-livrables.sh : prépare les livrables (archive, sommes de contrôle, preuves).
# À lancer sur hci1, en utilisateur hci :  bash ~/scripts/06-livrables.sh
set -euo pipefail

OUT=$HOME/livrables
VOL=vmstore
mkdir -p "$OUT"
cd "$HOME"

# La clé privée de cluster n'est jamais livrée : l'autre groupe la régénère.
tar czf "$OUT/hci-poc.tar.gz" --exclude='hci-poc/files/hci_id_ed25519*' hci-poc
[ -d "$HOME/scripts" ] && tar czf "$OUT/scripts.tar.gz" scripts

{
  echo "### Preuves générées le $(date -Is)"
  echo; echo "## ip -br a (hci1)";           ip -br a
  echo; echo "## hcictl status";             hcictl status
  echo; echo "## hcictl list";               hcictl list
  echo; echo "## gluster peer status";       sudo gluster peer status
  echo; echo "## gluster volume info";       sudo gluster volume info "$VOL"
  echo; echo "## gluster volume status";     sudo gluster volume status "$VOL"
  echo; echo "## gluster heal";              sudo gluster volume heal "$VOL" info summary
  echo; echo "## df";                        df -h /var/lib/libvirt/images/hci /data/brick1
  echo; echo "## disques des VM";            ls -lh /var/lib/libvirt/images/hci/disks
} > "$OUT/preuves.txt" 2>&1 || true

[ -f "$HOME/demo.log" ] && cp "$HOME/demo.log" "$OUT/demo.log"

cd "$OUT"
sha256sum ./*.tar.gz preuves.txt > SHA256SUMS
cat SHA256SUMS
echo
echo "Livrables dans $OUT"
echo "Les récupérer depuis le PC (PowerShell) :"
echo "  scp -r -J root@192.168.20.206 hci@10.10.10.11:~/livrables ."
echo "Somme de l'ISO Ubuntu (PowerShell) :"
echo "  Get-FileHash .\ubuntu-24.04*-live-server-amd64.iso -Algorithm SHA256"
