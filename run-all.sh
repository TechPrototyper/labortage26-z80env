#!/usr/bin/env bash
# Alles in einem Lauf - beliebig oft wiederholbar (jedes Teilskript ist idempotent).
set -euo pipefail
cd "$(dirname "$0")"
for s in 01-host.sh 02-vm.sh 03-provision.sh 04-repo.sh 05-test.sh 06-finish.sh; do
  printf '\n\033[1;35m######## %s ########\033[0m\n' "$s"
  ./"$s"
done
