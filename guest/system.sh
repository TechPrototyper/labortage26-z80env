#!/usr/bin/env bash
# Läuft als root in der VM. Idempotent: alles prüft vorher, was schon da ist.
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
: "${LAB_USER:?LAB_USER fehlt}"

log()  { printf '\033[1;34m  ->\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !!\033[0m %s\n' "$*" >&2; }
mkdir -p /var/lib/lab

# ---------------------------------------------------------------- Paketlisten
# Pflicht: fehlt eins davon, bricht das Skript ab.
REQUIRED="build-essential git make gdb pkg-config curl ca-certificates gnupg xz-utils unzip
  libmotif-dev libxt-dev libx11-dev libxext-dev x11-utils x11-xserver-utils xvfb xdotool imagemagick
  xfce4 xfce4-terminal lightdm lightdm-gtk-greeter dbus-x11 xserver-xorg-core xserver-xorg-input-libinput
  fonts-dejavu fonts-liberation mousepad locales zenity
  z80asm z80dasm sdcc pasmo cmake
  gcc-avr avr-libc binutils-avr avrdude
  picocom minicom socat lua5.4 xxd default-jre
  bison flex gzip clangd cppcheck
  libxml2-dev zlib1g-dev m4 ragel re2c dos2unix texinfo perl cpanminus libgmp-dev ccache
  libmodern-perl-perl libyaml-perl liblocal-lib-perl libcapture-tiny-perl libpath-tiny-perl libtext-table-perl
  libdata-hexdump-perl libregexp-common-perl libclone-perl libfile-slurp-perl libtemplate-perl libcpan-meta-perl"
# Optional/großzügig: nicht vorhandene Pakete werden übersprungen und gemeldet.
OPTIONAL="simavr clang-format valgrind universal-ctags srecord ghex
  flashrom python3-serial python3-venv pipx bear
  gtkwave iverilog openocd shellcheck tree htop texi2html"

avail() { LC_ALL=C apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print ($2 != "(none)" && $2 != "")}' | grep -q 1; }

log "apt update"
apt-get update -qq

log "Pflichtpakete"
# shellcheck disable=SC2086
apt-get install -y -qq $REQUIRED

log "Optionale Pakete"
want=(); skipped=()
for p in $OPTIONAL; do
  if avail "$p"; then want+=("$p"); else skipped+=("$p"); fi
done
[ ${#want[@]} -gt 0 ] && apt-get install -y -qq "${want[@]}" || true
[ ${#skipped[@]} -gt 0 ] && warn "In Debian 13 arm64 nicht verfügbar (übersprungen): ${skipped[*]}"
printf '%s\n' "${skipped[@]:-}" > /var/lib/lab/skipped-packages.txt

# ------------------------------------------------- Bildschirmsperre entfernen
# Das Lab-Konto hat kein Passwort; eine Sperre würde die Sitzung aussperren.
apt-get purge -y -qq xfce4-screensaver light-locker 2>/dev/null || true

# ------------------------------------------------------------ Locale/Tastatur
if ! locale -a | grep -qi '^de_DE.utf8'; then
  sed -i 's/^# *\(de_DE.UTF-8\)/\1/; s/^# *\(en_US.UTF-8\)/\1/' /etc/locale.gen
  locale-gen >/dev/null
fi
update-locale LANG=de_DE.UTF-8 >/dev/null
cat > /etc/default/keyboard <<'KBD'
XKBMODEL="pc105"
XKBLAYOUT="de"
XKBVARIANT=""
XKBOPTIONS=""
BACKSPACE="guess"
KBD
timedatectl set-timezone Europe/Berlin 2>/dev/null || ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime

# ------------------------------------------------------ Desktop / Autologin
mkdir -p /etc/lightdm/lightdm.conf.d
want_conf="[Seat:*]
autologin-user=$LAB_USER
autologin-user-timeout=0
autologin-session=xfce
"
if [ "$(cat /etc/lightdm/lightdm.conf.d/50-lab.conf 2>/dev/null)" != "${want_conf%$'\n'}" ]; then
  printf '%s' "$want_conf" > /etc/lightdm/lightdm.conf.d/50-lab.conf
  touch /var/lib/lab/needs-reboot; echo 1 > /var/lib/lab/needs-reboot
fi
echo /usr/sbin/lightdm > /etc/X11/default-display-manager
if [ "$(systemctl get-default)" != graphical.target ]; then
  systemctl set-default graphical.target
  echo 1 > /var/lib/lab/needs-reboot
fi
systemctl enable lightdm >/dev/null 2>&1 || true

# ------------------------------------------------------------------ VSCodium
# Offizielles Repo des VSCodium-Projekts (Open-Source-Build von VS Code ohne Telemetrie).
if ! dpkg -s codium >/dev/null 2>&1; then
  log "VSCodium installieren"
  curl -fsSL https://gitlab.com/paulcarroty/vscodium-deb-rpm-repo/raw/master/pub.gpg \
    | gpg --dearmor --yes -o /usr/share/keyrings/vscodium-archive-keyring.gpg
  cat > /etc/apt/sources.list.d/vscodium.sources <<'SRC'
Types: deb
URIs: https://download.vscodium.com/debs
Suites: vscodium
Components: main
Architectures: amd64 arm64
Signed-by: /usr/share/keyrings/vscodium-archive-keyring.gpg
SRC
  apt-get update -qq
  apt-get install -y -qq codium
else
  log "VSCodium bereits installiert"
fi

# ------------------------------------------- Aus gepinnten Quellen gebaut
# In Debian 13 nicht als Paket vorhanden. Commit-Hash wird nach dem Klonen geprüft.
build_from_git() { # name url commit binary-name [subdir]
  local name=$1 url=$2 commit=$3 bin=$4 sub=${5:-.} jobs=${6:-2}
  if [ -x "/usr/local/bin/$bin" ] && [ "$(cat "/var/lib/lab/$name.commit" 2>/dev/null)" = "$commit" ]; then
    log "$name bereits gebaut"; return
  fi
  log "Baue $name ($commit)"
  local d; d="$(mktemp -d)"
  git clone -q "$url" "$d/src"
  git -C "$d/src" checkout -q "$commit"
  [ "$(git -C "$d/src" rev-parse HEAD)" = "$commit" ] || { echo "Commit-Prüfung $name fehlgeschlagen" >&2; exit 1; }
  git -C "$d/src" submodule update --init --recursive -q
  (
    cd "$d/src/$sub"
    if [ -f CMakeLists.txt ]; then cmake -S . -B build -DCMAKE_BUILD_TYPE=Release >/dev/null && cmake --build build -j"$jobs" >/dev/null
    else make -j"$jobs" >/dev/null; fi
  )
  local exe; exe="$(find "$d/src" -type f -name "$bin" -perm -u+x | head -1)"
  [ -n "$exe" ] || { echo "$name: Binary $bin nicht gefunden" >&2; exit 1; }
  install -m 755 "$exe" "/usr/local/bin/$bin"
  echo "$commit" > "/var/lib/lab/$name.commit"
  rm -rf "$d"
}
build_from_git sjasmplus https://github.com/z00m128/sjasmplus d379eeac9ad3857fb48fd3a3929175d0a56038ce sjasmplus
build_from_git zmac     https://github.com/gp48k/zmac      050bbb1f9c608693d53b8827b991b5a9edc97a6b zmac src 1
build_from_git galasm    https://github.com/daveho/GALasm   eeb06645a5ef4a2fd4563908167b9294059a9204 galasm src

# ------------------------------------------------------------------- z88dk
# Z80-Standardtoolkit (zcc, sccz80, z80asm, appmake, Bibliotheken u.a. für TRS-80).
# Aus gepinnter Version gebaut, Installation in /opt/z88dk (dauert beim ersten Mal ~20 Min).
# Ohne zsdcc (SDCC-Fork, kostet noch einmal ~30 Min): Standardcompiler sccz80 funktioniert.
Z88DK_TAG=v2.5
Z88DK_COMMIT=37960a1a59b527839024992d6e3cc63772d5ba8f
Z88DK_DIR=/opt/z88dk
if [ "$(cat /var/lib/lab/z88dk.commit 2>/dev/null)" = "$Z88DK_COMMIT" ] && [ -x "$Z88DK_DIR/bin/zcc" ]; then
  log "z88dk $Z88DK_TAG bereits gebaut"
else
  log "Baue z88dk $Z88DK_TAG (dauert)"
  if [ ! -d "$Z88DK_DIR/.git" ]; then
    git clone -q https://github.com/z88dk/z88dk "$Z88DK_DIR"
  fi
  git -C "$Z88DK_DIR" fetch -q --tags origin
  git -C "$Z88DK_DIR" checkout -q -f "$Z88DK_COMMIT"
  [ "$(git -C "$Z88DK_DIR" rev-parse HEAD)" = "$Z88DK_COMMIT" ] || { echo "Commit-Prüfung z88dk fehlgeschlagen" >&2; exit 1; }
  git -C "$Z88DK_DIR" submodule update --init --recursive -q
  chown -R "$LAB_USER":"$LAB_USER" "$Z88DK_DIR"
  : > /var/lib/lab/z88dk-build.log; chown "$LAB_USER" /var/lib/lab/z88dk-build.log
  # Als Lab-Benutzer bauen (nicht als root), mit begrenzter Parallelität wegen RAM.
  if ! sudo -u "$LAB_USER" env BUILD_SDCC=0 BUILD_SDCC_HTTP=0 CC=gcc MAKEFLAGS=-j2 \
       bash -c "cd '$Z88DK_DIR' && nice ./build.sh -f > /var/lib/lab/z88dk-build.log 2>&1"; then
    tail -40 /var/lib/lab/z88dk-build.log >&2
    echo "z88dk-Build fehlgeschlagen (Log: /var/lib/lab/z88dk-build.log)" >&2
    exit 1
  fi
  echo "$Z88DK_COMMIT" > /var/lib/lab/z88dk.commit
fi
cat > /etc/profile.d/z88dk.sh <<'Z88'
export ZCCCFG=/opt/z88dk/lib/config
# Hinten anhängen: z88dk liefert ein eigenes "z80asm" mit, das den Adapter für das Projekt-Makefile
# (/usr/local/bin/z80asm) nicht überdecken darf. zcc nutzt intern die Namen z88dk-z80asm usw.
case ":$PATH:" in *":/opt/z88dk/bin:"*) ;; *) export PATH="$PATH:/opt/z88dk/bin" ;; esac
Z88
# auch für Terminals ohne Login-Shell
grep -q 'z88dk.sh' /etc/bash.bashrc || printf '\n[ -r /etc/profile.d/z88dk.sh ] && . /etc/profile.d/z88dk.sh\n' >> /etc/bash.bashrc

# --------------------------------------------- z80asm-Adapter für das Makefile
# Das Projekt-Makefile ruft `z80asm -l<Liste> -o <ROM> firmware.z8a` auf. Die Firmware nutzt
# Syntax, die Debians z80asm (Bas Wijnen 1.8) und Udo Munks z80asm nicht übersetzen
# (z.B. ixl/ixh, "add c"). sjasmplus übersetzt sie fehlerfrei; dieser Adapter übersetzt
# den Aufruf, damit `make` unverändert funktioniert. Debians /usr/bin/z80asm bleibt unberührt.
cat > /usr/local/bin/z80asm <<'WRAP'
#!/bin/sh
# Adapter: z80asm-Aufruf des Labcomp-Makefiles -> sjasmplus
lst=""; out=""; src=""
while [ $# -gt 0 ]; do
  case "$1" in
    -l) ;;
    -l*) lst="${1#-l}" ;;
    -o) shift; out="$1" ;;
    -o*) out="${1#-o}" ;;
    -*) ;;
    *) src="$1" ;;
  esac
  shift
done
[ -n "$src" ] && [ -n "$out" ] || { echo "usage: z80asm [-l<list>] -o <rom> <source>" >&2; exit 2; }
exec sjasmplus --nologo --dirbol --raw="$out" ${lst:+--lst="$lst"} "$src"
WRAP
chmod 755 /usr/local/bin/z80asm

# ----------------------------------------------------------- Logisim-evolution
# Schaltplan-Simulator (öffnet AddrDec.circ). Jar von GitHub, SHA-256 gepinnt.
LOGISIM_VER=5.0.0
LOGISIM_SHA=6b368e894742c04cc83aa9830f869bcab0190ede4df43ad6fecdb89b3a23a41c
LOGISIM_JAR=/opt/logisim-evolution/logisim-evolution-$LOGISIM_VER-all.jar
if [ ! -f "$LOGISIM_JAR" ] || ! echo "$LOGISIM_SHA  $LOGISIM_JAR" | sha256sum -c --status; then
  log "Logisim-evolution $LOGISIM_VER laden"
  mkdir -p /opt/logisim-evolution
  curl -fsSL -o "$LOGISIM_JAR.part" \
    "https://github.com/logisim-evolution/logisim-evolution/releases/download/v$LOGISIM_VER/logisim-evolution-$LOGISIM_VER-all.jar"
  echo "$LOGISIM_SHA  $LOGISIM_JAR.part" | sha256sum -c --status || { rm -f "$LOGISIM_JAR.part"; echo "Prüfsumme Logisim falsch" >&2; exit 1; }
  mv "$LOGISIM_JAR.part" "$LOGISIM_JAR"
fi
cat > /usr/local/bin/logisim <<LS
#!/bin/sh
exec java -jar $LOGISIM_JAR "\$@"
LS
chmod 755 /usr/local/bin/logisim

# ------------------------------------------------------------ pymcuprog (UPDI)
if command -v pipx >/dev/null && ! [ -x /usr/local/bin/pymcuprog ]; then
  PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install pymcuprog >/dev/null 2>&1 \
    || warn "pymcuprog konnte nicht installiert werden (optional)"
fi

# --------------------------------------------------------------- Diagnose
modinfo virtio_gpu >/dev/null 2>&1 && log "Kernel hat virtio_gpu" || warn "Kernel ohne virtio_gpu: $(uname -r)"
log "system.sh fertig"
