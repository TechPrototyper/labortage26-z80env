#!/usr/bin/env bash
# Läuft als Lab-Benutzer, nachdem das Repo geklont ist: Desktop-Starter mit Logo-Icon, als vertrauenswürdig markiert.
set -euo pipefail
export LC_ALL=C.UTF-8
log() { printf '\033[1;34m  ->\033[0m %s\n' "$*"; }

mkdir -p "$HOME/Desktop" "$HOME/.local/share/icons"
icon="$HOME/.local/share/icons/labcomp.png"
convert "$HOME/Projects/labortage/labcomp/LaborLogo.xbm" -negate -resize 128x128 -background '#1b2a49' -gravity center -extent 160x160 "$icon" 2>/dev/null || true
[ -f "$icon" ] || icon=utilities-terminal

# --- Anzeigegröße: Skript "labzoom" mit drei Stufen (Auflösung + DPI + Schrift + Panel/Symbole) ---
mkdir -p "$HOME/.local/bin" "$HOME/.config/labzoom" "$HOME/.config/autostart"
cat > "$HOME/.labzoom.tmp" <<'ZOOM'
#!/bin/bash
# labzoom [normal|gross|riesig|pick|apply]
#   normal : 1920x1200, 120 dpi   (viel Platz)
#   gross  : 1440x900,  144 dpi   (Standard; gut lesbar, passt auch auf 13"-Bildschirme)
#   riesig : 1280x800,  168 dpi   (maximale Lesbarkeit)
# Die Auswahl wird gemerkt und bei jeder Anmeldung angewendet.
cfg="$HOME/.config/labzoom/preset"
cmd="${1:-pick}"
if [ "$cmd" = pick ]; then
  cur="$(cat "$cfg" 2>/dev/null || echo gross)"
  cmd="$(zenity --list --radiolist --title="Anzeigegröße" --text="Schriftgröße und Auflösung wählen" \
    --column="" --column="Stufe" --column="Beschreibung" --hide-header --width=520 --height=300 \
    $([ "$cur" = normal ] && echo TRUE || echo FALSE) normal "Normal (1920x1200, viel Platz)" \
    $([ "$cur" = gross ] && echo TRUE || echo FALSE)  gross  "Groß (1440x900, empfohlen)" \
    $([ "$cur" = riesig ] && echo TRUE || echo FALSE) riesig "Riesig (1280x800, maximal lesbar)" \
    --print-column=2 2>/dev/null)" || exit 0
  [ -n "$cmd" ] || exit 0
fi
[ "$cmd" = apply ] && cmd="$(cat "$cfg" 2>/dev/null || echo gross)"
case "$cmd" in
  normal) mode=1920x1200; dpi=120; font="Sans 10"; mono="Monospace 10"; panel=32; dock=48; icons=48; cursor=24 ;;
  gross)  mode=1440x900;  dpi=144; font="Sans 11"; mono="Monospace 11"; panel=40; dock=56; icons=64; cursor=32 ;;
  riesig) mode=1280x800;  dpi=168; font="Sans 11"; mono="Monospace 11"; panel=48; dock=64; icons=72; cursor=40 ;;
  *) echo "usage: labzoom [normal|gross|riesig|pick|apply]" >&2; exit 2 ;;
esac
echo "$cmd" > "$cfg"
export DISPLAY="${DISPLAY:-:0}" XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
out="$(xrandr | awk '/ connected/ {print $1; exit}')"
[ -n "$out" ] && xrandr --output "$out" --mode "$mode" 2>/dev/null
xq() { xfconf-query -c "$1" -p "$2" -n -t "$3" -s "$4" 2>/dev/null; }
xq xsettings /Xft/DPI int "$dpi"
xq xsettings /Gtk/FontName string "$font"
xq xsettings /Gtk/MonospaceFontName string "$mono"
xq xsettings /Gtk/CursorThemeSize int "$cursor"
xq xfce4-panel /panels/panel-1/size uint "$panel"
xq xfce4-panel /panels/panel-2/size uint "$dock"
xq xfce4-desktop /desktop-icons/icon-size uint "$icons"
echo "Anzeigegröße: $cmd ($mode, $dpi dpi). Bereits offene Programme (z.B. die IDE) bitte neu starten."
ZOOM
# systemweit installieren (/usr/local/bin ist immer im PATH, ~/.local/bin erst nach neuer Anmeldung)
sudo install -m 755 "$HOME/.labzoom.tmp" /usr/local/bin/labzoom
rm -f "$HOME/.labzoom.tmp" "$HOME/.local/bin/labzoom"
cat > "$HOME/.config/autostart/labzoom.desktop" <<AUTO
[Desktop Entry]
Type=Application
Name=Anzeigegröße anwenden
Exec=/usr/local/bin/labzoom apply
Terminal=false
X-GNOME-Autostart-Phase=Initialization
AUTO

# Standard-Browser: Chromium (Debian). Google Chrome gibt es für Linux nur für x86_64, nicht für ARM64.
xdg-settings set default-web-browser chromium.desktop >/dev/null 2>&1 || true
mkdir -p "$HOME/.config/xfce4"
if grep -q '^WebBrowser=' "$HOME/.config/xfce4/helpers.rc" 2>/dev/null; then
  sed -i 's/^WebBrowser=.*/WebBrowser=chromium/' "$HOME/.config/xfce4/helpers.rc"
else
  echo 'WebBrowser=chromium' >> "$HOME/.config/xfce4/helpers.rc"
fi

# Workspace mit Projekt und Beispielen, damit beides in der IDE sichtbar ist
cat > "$HOME/Lab.code-workspace" <<'WS'
{
  "folders": [
    { "name": "code (liegt auf dem Mac)", "path": "Projects/labortage/code" },
    { "name": "labcomp (Projekt)", "path": "Projects/labortage/labcomp" },
    { "name": "examples (Beispiele)", "path": "Projects/labortage/labortage26-z80env/examples" }
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
mk labcomp-emu     "Labcomp Emulator"      "sh -c 'cd \$HOME/Projects/labortage/labcomp && exec ./labcomp_emu'" "$icon"
mk labcomp-ide     "Labcomp IDE"           "codium \$HOME/Lab.code-workspace"               vscodium
mk labcomp-logisim "Logisim (Schaltplan)"  "sh -c 'cd \$HOME/Projects/labortage/labcomp && exec logisim AddrDec.circ'" applications-engineering
mk labcomp-zoom     "Anzeigegröße"          "/usr/local/bin/labzoom pick"                         preferences-desktop-font
mk labcomp-term    "Terminal"              "xfce4-terminal --working-directory=\$HOME/Projects/labortage/labcomp" utilities-terminal

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

# Gewählte Anzeigegröße sofort in der laufenden Sitzung anwenden (nicht kritisch, wenn keine Sitzung läuft)
/usr/local/bin/labzoom apply || true
