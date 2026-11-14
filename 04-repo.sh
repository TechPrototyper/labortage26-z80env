#!/usr/bin/env bash
# d) Repo in der VM bereitstellen (idempotent: klont beim ersten Mal, danach fast-forward Pull).
source "$(dirname "$0")/lib.sh"
vm_running || die "VM läuft nicht - erst 02-vm.sh"
REMOTE="$LABCOMP_REPO_URL"

vm_sh bash -s "$REMOTE" <<'GUEST'
set -euo pipefail
remote="$1"; dir="$HOME/labcomp"
if [ -d "$dir/.git" ]; then
  echo "  -> Repo vorhanden, aktualisiere"
  git -C "$dir" pull --ff-only
else
  echo "  -> Klone $remote"
  git clone "$remote" "$dir"
fi
git -C "$dir" log --oneline -1
GUEST

# Beispiele aus diesem Repo nach ~/examples in der VM (idempotent: wird überschrieben)
log "Beispiele nach ~/examples kopieren"
vm_sh bash -c 'mkdir -p "$HOME/examples"'
limactl copy "$LAB_DIR"/examples/* "$VM_NAME:examples/"

log "Desktop-Starter"
vm_sh bash -s < "$LAB_DIR/guest/desktop.sh"
