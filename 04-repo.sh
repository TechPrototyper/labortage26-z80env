#!/usr/bin/env bash
# d) Projektverzeichnisse in der VM einrichten (idempotent):
#   ~/Projects/labortage/labcomp               geklontes Labcomp-Projekt
#   ~/Projects/labortage/labortage26-z80env    dieses Repository (enthält examples/)
#   ~/Projects/labortage/code                  Verknüpfung auf den Mac-Ordner $LAB_CODE_DIR (eigener Code, bleibt erhalten)
source "$(dirname "$0")/lib.sh"
vm_running || die "VM läuft nicht - erst 02-vm.sh"

# Mac-Ordner für eigenen Code anlegen und mit einem Startbeispiel füllen (vorhandene Dateien bleiben unangetastet)
mkdir -p "$LAB_CODE_DIR/.vscode"
cp -n "$LAB_DIR/examples/hello.z8a" "$LAB_CODE_DIR/hello.z8a" 2>/dev/null || true
cp -n "$LAB_DIR/examples/.vscode/tasks.json" "$LAB_CODE_DIR/.vscode/tasks.json" 2>/dev/null || true
case "$LAB_CODE_DIR" in
  "$HOME/LabShare"/*|"$HOME/LabShare") ;;
  *) warn "LAB_CODE_DIR liegt außerhalb von ~/LabShare - dann muss der Ordner in lab.yaml als Mount eingetragen sein" ;;
esac

vm_sh bash -s "$LABCOMP_REPO_URL" "$LAB_ENV_REPO_URL" <<'GUEST'
set -euo pipefail
base="$HOME/Projects/labortage"
mkdir -p "$base"
clone_or_pull() { # url dir
  if [ -d "$2/.git" ]; then
    echo "  -> $(basename "$2") vorhanden, aktualisiere"
    git -C "$2" pull --ff-only
  else
    echo "  -> Klone $1"
    git clone "$1" "$2"
  fi
  git -C "$2" log --oneline -1
}
clone_or_pull "$1" "$base/labcomp"
clone_or_pull "$2" "$base/labortage26-z80env"
# Altlasten früherer Skriptversionen (~/labcomp, ~/examples im Home) entfernen, aber nur, wenn nichts Eigenes drinsteckt
if [ -d "$HOME/labcomp/.git" ]; then
  if [ -z "$(git -C "$HOME/labcomp" status --porcelain)" ] && [ -z "$(git -C "$HOME/labcomp" log '@{u}..HEAD' 2>/dev/null)" ]; then
    rm -rf "$HOME/labcomp"; echo "  -> ~/labcomp (unverändert, liegt jetzt unter Projects/labortage) entfernt"
  else
    echo "  !! ~/labcomp hat lokale Änderungen - nicht gelöscht, bitte prüfen" >&2
  fi
fi
if [ -d "$HOME/examples" ]; then
  if diff -r "$HOME/examples" "$base/labortage26-z80env/examples" >/dev/null 2>&1; then
    rm -rf "$HOME/examples"; echo "  -> ~/examples (Kopie der Beispiele) entfernt"
  else
    echo "  !! ~/examples weicht von den Beispielen im Repo ab - nicht gelöscht, bitte prüfen" >&2
  fi
fi
# Verknüpfung auf den Mac-Ordner (virtiofs-Mount /mnt/labshare)
ln -sfn /mnt/labshare/code "$base/code"
[ -d "$base/code" ] || { echo "  !! $base/code zeigt ins Leere - ist der Mount /mnt/labshare vorhanden?" >&2; exit 1; }
GUEST

log "Desktop-Starter"
vm_sh bash -s < "$LAB_DIR/guest/desktop.sh"
