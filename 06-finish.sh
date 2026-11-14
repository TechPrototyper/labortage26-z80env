#!/usr/bin/env bash
# f) VM sauber herunterfahren und StartLab-Icon auf den Schreibtisch legen (idempotent).
source "$(dirname "$0")/lib.sh"

# Logo für das Icon aus dem Projekt in der VM holen (solange sie noch läuft)
LOGO="$HOME/.cache/lab/LaborLogo.xbm"
if vm_running; then
  mkdir -p "$(dirname "$LOGO")"
  limactl copy "$VM_NAME:labcomp/LaborLogo.xbm" "$LOGO" 2>/dev/null || true
fi

if [ "${LAB_NO_STOP:-0}" = 1 ]; then
  log "LAB_NO_STOP=1: VM bleibt an"
elif vm_running; then
  log "Fahre VM herunter"
  limactl stop "$VM_NAME"
else
  log "VM ist bereits aus ($(vm_status))"
fi

APP_FINAL="$HOME/Desktop/StartLab.app"
# Im Temp-Verzeichnis bauen und signieren: der (iCloud-)Schreibtisch hängt Finder-Attribute an,
# mit denen codesign sich weigert.
BUILD="$(mktemp -d)"
APP="$BUILD/StartLab.app"
log "Erzeuge $APP_FINAL"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

# Icon aus dem Labor-Logo des Projekts (LaborLogo.xbm)
tmp="$(mktemp -d)"
mkdir "$tmp/StartLab.iconset"
if [ -s "$LOGO" ] && command -v magick >/dev/null; then
  magick "$LOGO" -negate -resize 760x760 -background '#1b2a49' -gravity center -extent 1024x1024 "$tmp/icon.png"
  for s in 16 32 128 256 512; do
    sips -z $s $s "$tmp/icon.png" --out "$tmp/StartLab.iconset/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) "$tmp/icon.png" --out "$tmp/StartLab.iconset/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$tmp/StartLab.iconset" -o "$APP/Contents/Resources/StartLab.icns"
else
  warn "Kein Logo/ImageMagick - StartLab bekommt das Standard-Icon (brew install imagemagick, dann 06-finish.sh erneut)"
fi
rm -rf "$tmp"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>StartLab</string>
  <key>CFBundleDisplayName</key><string>StartLab</string>
  <key>CFBundleIdentifier</key><string>local.labcomp.startlab</string>
  <key>CFBundleExecutable</key><string>StartLab</string>
  <key>CFBundleIconFile</key><string>StartLab</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>13.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST

cat > "$APP/Contents/MacOS/StartLab" <<STARTER
#!/bin/bash
# Startet die Lab-VM; das VM-Fenster öffnet sich über Apples Virtualization.framework.
export PATH=/opt/homebrew/bin:/usr/local/bin:\$PATH
export LIMA_HOME="$LIMA_HOME"
VM="$VM_NAME"
LOG="\$HOME/Library/Logs/StartLab.log"
note() { osascript -e "display notification \"\$1\" with title \"StartLab\"" >/dev/null 2>&1; }
if [ "\$(limactl list --format '{{.Status}}' "\$VM" 2>/dev/null)" = "Running" ]; then
  note "Die Lab-VM läuft bereits."
  exit 0
fi
note "Lab-VM wird gestartet ..."
mkdir -p "\$HOME/LabShare"
if limactl start --tty=false "\$VM" >>"\$LOG" 2>&1; then
  note "Lab-VM läuft."
else
  osascript -e 'display dialog "Die Lab-VM konnte nicht gestartet werden. Details: ~/Library/Logs/StartLab.log" buttons {"OK"} with icon stop' >/dev/null 2>&1
  exit 1
fi
STARTER
chmod 755 "$APP/Contents/MacOS/StartLab"
codesign --force --sign - "$APP" >/dev/null 2>&1 || warn "codesign übersprungen"
rm -rf "$APP_FINAL"
ditto --noextattr --norsrc "$APP" "$APP_FINAL"
rm -rf "$BUILD"
log "Fertig: $APP_FINAL"
