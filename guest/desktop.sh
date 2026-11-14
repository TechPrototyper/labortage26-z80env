#!/usr/bin/env bash
# Läuft als Lab-Benutzer, nachdem das Repo geklont ist: Desktop-Starter mit Logo-Icon, als vertrauenswürdig markiert.
set -euo pipefail
log() { printf '\033[1;34m  ->\033[0m %s\n' "$*"; }

mkdir -p "$HOME/Desktop" "$HOME/.local/share/icons"
icon="$HOME/.local/share/icons/labcomp.png"
convert "$HOME/labcomp/LaborLogo.xbm" -negate -resize 128x128 -background '#1b2a49' -gravity center -extent 160x160 "$icon" 2>/dev/null || true
[ -f "$icon" ] || icon=utilities-terminal

# Workspace mit Projekt und Beispielen, damit beides in der IDE sichtbar ist
cat > "$HOME/Lab.code-workspace" <<'WS'
{
  "folders": [
    { "name": "labcomp (Projekt)", "path": "labcomp" },
    { "name": "examples (Beispiele)", "path": "examples" }
  ]
}
WS

mk() { # mk <Datei> <Name> <Exec> <Icon>
  f="$HOME/Desktop/$1.desktop"
  cat > "$f" <<DESK
[Desktop Entry]
Type=Application
Name=$2
Exec=$3
Icon=$4
Terminal=false
StartupNotify=false
DESK
  chmod +x "$f"
}
mk labcomp-emu     "Labcomp Emulator"      "sh -c 'cd \$HOME/labcomp && exec ./labcomp_emu'" "$icon"
mk labcomp-ide     "Labcomp IDE"           "codium \$HOME/Lab.code-workspace"               vscodium
mk labcomp-logisim "Logisim (Schaltplan)"  "sh -c 'cd \$HOME/labcomp && exec logisim AddrDec.circ'" applications-engineering
mk labcomp-term    "Terminal"              "xfce4-terminal --working-directory=\$HOME/labcomp" utilities-terminal

# Als vertrauenswürdig markieren (sonst fragt XFCE bei jedem Start nach). Braucht den Session-Bus.
bus="/run/user/$(id -u)/bus"
if [ -S "$bus" ]; then
  for f in "$HOME"/Desktop/labcomp-*.desktop; do
    sum="$(sha256sum "$f" | cut -d' ' -f1)"
    DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" gio set -t string "$f" metadata::xfce-exe-checksum "$sum" 2>/dev/null \
      && DBUS_SESSION_BUS_ADDRESS="unix:path=$bus" gio set "$f" metadata::trusted true 2>/dev/null || true
  done
else
  echo "  !! kein Session-Bus - Starter nicht als vertrauenswürdig markiert (beim ersten Start bestätigen)" >&2
fi
log "Desktop-Starter angelegt"
