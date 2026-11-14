# Gemeinsame Helfer für alle Lab-Skripte. Wird mit `source` eingebunden.
set -euo pipefail

LAB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Das Labcomp-Projekt, das in der VM geklont wird (überschreibbar, z.B. für einen eigenen Fork).
LABCOMP_REPO_URL="${LABCOMP_REPO_URL:-https://git.gay/ayron/labcomp}"
VM_NAME="${VM_NAME:-lab}"
export LIMA_HOME="${LIMA_HOME:-$HOME/.lima}"
for p in /opt/homebrew/bin /usr/local/bin; do
  case ":$PATH:" in *":$p:"*) ;; *) PATH="$p:$PATH" ;; esac
done
export PATH

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m %s\n' "$*" >&2; exit 1; }

vm_exists()  { limactl list -q 2>/dev/null | grep -qx "$VM_NAME"; }
vm_status()  { limactl list --format '{{.Status}}' "$VM_NAME" 2>/dev/null || echo "Missing"; }
vm_running() { [ "$(vm_status)" = "Running" ]; }
# Befehl als Lab-Benutzer in der VM ausführen
vm_sh()      { limactl shell --workdir / "$VM_NAME" -- "$@"; }
