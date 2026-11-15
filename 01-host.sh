#!/usr/bin/env bash
# a) Hypervisor-Tooling auf dem Mac einrichten (idempotent).
# Lima nutzt Apples Virtualization.framework (vz): nahezu nativ, sparsam, kein XQuartz.
source "$(dirname "$0")/lib.sh"

[ "$(uname -s)" = Darwin ] && [ "$(uname -m)" = arm64 ] || die "Nur für Apple Silicon gedacht."
command -v brew >/dev/null || die "Homebrew fehlt: https://brew.sh"

for f in lima imagemagick zstd; do
  if brew list --formula "$f" >/dev/null 2>&1; then
    log "$f bereits installiert ($(brew list --versions "$f"))"
  else
    log "Installiere $f"
    brew install "$f"
  fi
done
limactl --version
