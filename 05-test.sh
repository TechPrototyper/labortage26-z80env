#!/usr/bin/env bash
# e) Test des Labs in der VM (idempotent, baut immer neu).
source "$(dirname "$0")/lib.sh"
vm_running || die "VM läuft nicht - erst 02-vm.sh"
vm_sh bash -s < "$LAB_DIR/guest/test.sh"
