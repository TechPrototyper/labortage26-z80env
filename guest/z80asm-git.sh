#!/usr/bin/env bash
# Als root: z80asm aus dem Git-Repository von Savannah (Bas Wijnen) als ALTERNATIVE. Nichts wird überschrieben:
#   /opt/z80asm-git/bin/z80asm   die Alternative (nicht im PATH)
#   /usr/local/bin/z80asm-git    Verknüpfung darauf
# Warum: Die letzte Release 1.8 (2009, = Debians Paket) kennt `inc ixl` & Co. nicht; im Git-Stand (1.9, 16.03.2021, nie als Release
# erschienen) sind sie korrigiert. Dieser Stand versteht den unveränderten Makefile-Aufruf `z80asm -lfirmware.prn -o rom firmware.z8a`.
# Gebaut ohne autotools: das Projekt besteht aus wenigen C-Dateien, eine kleine config.h ersetzt `configure`.
set -euo pipefail
export LC_ALL=C.UTF-8
log() { printf '\033[1;34m  ->\033[0m %s\n' "$*"; }

COMMIT=0df4a46551adb0dd8abbb3c3b0442f6cb37c6cc2
PREFIX=/opt/z80asm-git
if [ -x "$PREFIX/bin/z80asm" ] && [ "$(cat /var/lib/lab/z80asm-git.commit 2>/dev/null)" = "$COMMIT" ]; then
  log "z80asm-git bereits gebaut"; exit 0
fi

log "Baue z80asm (Savannah-Git, $COMMIT)"
d="$(mktemp -d)"
git clone -q https://git.savannah.gnu.org/git/z80asm.git "$d/src"
git -C "$d/src" checkout -q "$COMMIT"
[ "$(git -C "$d/src" rev-parse HEAD)" = "$COMMIT" ] || { echo "Commit-Prüfung z80asm-git fehlgeschlagen" >&2; exit 1; }
cd "$d/src"
cat > config.h <<CFG
#define PACKAGE "z80asm"
#define VERSION "1.9-git-${COMMIT:0:7}"
#define LOCALEDIR "$PREFIX/share/locale"
#define HAVE_LOCALE_H 1
#define ENABLE_NLS 0
CFG
cc -O2 -w -I. -Iinclude -DHAVE_CONFIG_H -DPKGDATADIR="\"$PREFIX/share/z80asm\"" -o z80asm src/*.c
mkdir -p "$PREFIX/bin" "$PREFIX/share/z80asm/headers"
install -m 755 z80asm "$PREFIX/bin/z80asm"
install -m 644 data/headers/*.asm "$PREFIX/share/z80asm/headers/"
ln -sfn "$PREFIX/bin/z80asm" /usr/local/bin/z80asm-git
echo "$COMMIT" > /var/lib/lab/z80asm-git.commit
cd /; rm -rf "$d"
log "z80asm-git installiert: $PREFIX/bin/z80asm  (Verknüpfung: /usr/local/bin/z80asm-git)"
