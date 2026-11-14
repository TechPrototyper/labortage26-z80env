#!/usr/bin/env bash
# c1/c2) Software in der VM installieren (idempotent; mehrfach ausführbar).
source "$(dirname "$0")/lib.sh"
vm_running || die "VM läuft nicht - erst 02-vm.sh"

LAB_USER="$(vm_sh id -un)"
log "Systempakete, Desktop, Toolchains (als root)"
limactl shell --workdir / "$VM_NAME" -- sudo env LAB_USER="$LAB_USER" bash -s < "$LAB_DIR/guest/system.sh"

# trszog (privates Repo TechPrototyper/trszog, TRS-80-Edition von DeZog): fertiges Pre-Release-VSIX über die
# gh-Anmeldung des Macs laden, SHA-256 prüfen und in die VM kopieren. Ohne gh/Zugriff (TRSZOG=off oder
# Zugriff fehlt) wird stattdessen das Original-DeZog installiert (siehe guest/user.sh).
TRSZOG_TAG="v3.7.4-rc1-trs80.4"
TRSZOG_VSIX="$HOME/.cache/lab/trszog-$TRSZOG_TAG.vsix"
TRSZOG_PIN="$LAB_DIR/pins/trszog-$TRSZOG_TAG.sha256"
have_trszog=0
if [ "${TRSZOG:-auto}" != off ]; then
  if [ ! -f "$TRSZOG_VSIX" ] && command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
    log "Lade trszog $TRSZOG_TAG (privates Repo)"
    mkdir -p "$(dirname "$TRSZOG_VSIX")"
    if gh release download "$TRSZOG_TAG" -R TechPrototyper/trszog -p trszog.vsix -O "$TRSZOG_VSIX.part" --clobber 2>/dev/null; then
      mv "$TRSZOG_VSIX.part" "$TRSZOG_VSIX"
    else
      rm -f "$TRSZOG_VSIX.part"; warn "Kein Zugriff auf TechPrototyper/trszog - nehme das Original-DeZog"
    fi
  fi
  if [ -f "$TRSZOG_VSIX" ]; then
    sum="$(shasum -a 256 "$TRSZOG_VSIX" | cut -d' ' -f1)"
    if [ -f "$TRSZOG_PIN" ]; then
      [ "$(cat "$TRSZOG_PIN")" = "$sum" ] || die "trszog-VSIX stimmt nicht mit pins/$(basename "$TRSZOG_PIN") überein"
    else
      echo "$sum" > "$TRSZOG_PIN"; log "trszog-Prüfsumme festgehalten: $sum"
    fi
    limactl copy "$TRSZOG_VSIX" "$VM_NAME:/tmp/trszog.vsix"
    have_trszog=1
  fi
fi
[ "$have_trszog" = 1 ] || limactl shell --workdir / "$VM_NAME" -- rm -f /tmp/trszog.vsix

log "IDE-Erweiterungen (als $LAB_USER)"
vm_sh bash -s < "$LAB_DIR/guest/user.sh"

log "KI-Werkzeuge: Node.js (root)"
limactl shell --workdir / "$VM_NAME" -- sudo bash -s < "$LAB_DIR/guest/ai-root.sh"
log "KI-Werkzeuge: Claude Code, OpenCode, Qwen Code, Erweiterungen (als $LAB_USER)"
vm_sh bash -s < "$LAB_DIR/guest/ai-user.sh"

# Falls der Kernel/Desktop frisch installiert wurde: einmal neu starten, damit Autologin greift.
if [ "$(vm_sh cat /var/lib/lab/needs-reboot 2>/dev/null || true)" = "1" ]; then
  log "Neustart der VM (Kernel/Desktop-Konfiguration)"
  limactl stop "$VM_NAME"
  limactl start --tty=false "$VM_NAME"
  limactl shell --workdir / "$VM_NAME" -- sudo rm -f /var/lib/lab/needs-reboot
fi
