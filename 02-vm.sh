#!/usr/bin/env bash
# b) Lab-VM anlegen und starten (idempotent).
source "$(dirname "$0")/lib.sh"
command -v limactl >/dev/null || die "limactl fehlt - erst 01-host.sh ausführen"

mkdir -p "$HOME/LabShare"

# Image selbst laden (fortsetzbar, IPv4, mit Wiederholung) und per SHA-512 prüfen;
# Lima bricht bei Netzwerk-Timeouts sonst komplett ab.
IMG_URL="$(sed -n 's/^- location: "\(.*\)"/\1/p' "$LAB_DIR/lab.yaml" | head -1)"
IMG_SHA="$(sed -n 's/^  digest: "sha512:\(.*\)"/\1/p' "$LAB_DIR/lab.yaml" | head -1)"
IMG="$HOME/.cache/lab/$(basename "$IMG_URL")"
fetch_image() {
  mkdir -p "$(dirname "$IMG")"
  if [ -f "$IMG" ] && [ "$(shasum -a 512 "$IMG" | cut -d' ' -f1)" = "$IMG_SHA" ]; then
    log "Image im Cache: $IMG"; return
  fi
  log "Lade $(basename "$IMG") (ca. 400 MB, fortsetzbar)"
  for i in 1 2 3 4 5 6; do
    curl -4 -fL --connect-timeout 20 --speed-limit 50000 --speed-time 30 -C - -o "$IMG.part" "$IMG_URL" && break
    warn "Download-Versuch $i fehlgeschlagen, neuer Versuch"; sleep 3
  done
  [ "$(shasum -a 512 "$IMG.part" | cut -d' ' -f1)" = "$IMG_SHA" ] || { rm -f "$IMG.part"; die "Prüfsumme des Images stimmt nicht"; }
  mv "$IMG.part" "$IMG"
}

# Halb angelegte Instanz (z.B. nach abgebrochenem Download) aufräumen
if vm_exists && [ ! -f "$LIMA_HOME/$VM_NAME/diffdisk" ] && [ "$(vm_status)" = "Stopped" ]; then
  warn "Unvollständige VM gefunden - lege sie neu an"
  limactl delete --force "$VM_NAME"
fi

if vm_exists; then
  log "VM '$VM_NAME' existiert bereits (Status: $(vm_status))"
else
  fetch_image
  log "Lege VM '$VM_NAME' an"
  limactl create --tty=false --name="$VM_NAME" \
    --set ".images = [{\"location\": \"$IMG\", \"arch\": \"aarch64\", \"digest\": \"sha512:$IMG_SHA\"}]" \
    "$LAB_DIR/lab.yaml"
fi

if vm_running; then
  log "VM läuft bereits"
else
  log "Starte VM"
  limactl start --tty=false "$VM_NAME"
fi
vm_sh uname -a
