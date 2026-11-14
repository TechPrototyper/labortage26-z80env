#!/usr/bin/env bash
# Läuft als Lab-Benutzer in der VM: IDE-Erweiterungen, Desktop-Starter, Editor-Einstellungen.
set -euo pipefail
log()  { printf '\033[1;34m  ->\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !!\033[0m %s\n' "$*" >&2; }
export LC_ALL=C.UTF-8

installed="$(codium --list-extensions 2>/dev/null | tr 'A-Z' 'a-z' || true)"
ext() { # ext <id>  (Open VSX)
  if grep -qix "$1" <<<"$installed"; then log "Erweiterung $1 vorhanden"; return; fi
  if codium --install-extension "$1" >/dev/null 2>&1; then log "Erweiterung $1 installiert"
  else warn "Erweiterung $1 nicht installierbar (übersprungen)"; fi
}

for id in \
  mborik.z80-macroasm theNestruo.z80-asm-meter maziac.asm-code-lens emulicious.emulicious-debugger \
  llvm-vs-code-extensions.vscode-clangd webfreak.debug ms-vscode.makefile-tools \
  ms-vscode.hexeditor sumneko.lua editorconfig.editorconfig \
  eamodio.gitlens mhutchie.git-graph usernamehw.errorlens; do
  ext "$id"
done

# trszog (TechPrototyper-Fork von DeZog, TRS-80-Edition, ID techprototyper.dezog): VSIX kommt vom Mac
# (privates Repo). Das Original maziac.dezog wird entfernt, beide zusammen würden kollidieren.
vsix=/tmp/trszog.vsix
if [ -f "$vsix" ] && codium --list-extensions 2>/dev/null | grep -qix 'maziac.dezog'; then
  codium --uninstall-extension maziac.dezog >/dev/null 2>&1 && log "Original-DeZog entfernt" || warn "Original-DeZog nicht entfernbar"
fi
if [ -f "$vsix" ]; then
  want="$(unzip -p "$vsix" extension/package.json | python3 -c 'import sys,json; print(json.load(sys.stdin)["version"])')"
  have="$(codium --list-extensions --show-versions 2>/dev/null | grep -i '^techprototyper.dezog@' | cut -d@ -f2 || true)"
  if [ "$have" = "$want" ]; then
    log "trszog $want bereits installiert"
  else
    codium --install-extension "$vsix" --force >/dev/null 2>&1 && log "trszog $want installiert (vorher: ${have:-keine})" \
      || { warn "trszog konnte nicht installiert werden"; exit 1; }
  fi
else
  # Fallback ohne trszog: Original-DeZog (maziac) von GitHub, Prüfsumme gepinnt.
  DEZOG_VER=3.7.0
  DEZOG_SHA=f0d51d94e4e3a387aaaf34b9607b3cee7d1e1ff24e3385485e782b6373782afb
  if codium --list-extensions 2>/dev/null | grep -qix 'maziac.dezog' || codium --list-extensions 2>/dev/null | grep -qix 'techprototyper.dezog'; then
    log "DeZog/trszog bereits installiert"
  else
    tmp="$(mktemp -d)"
    curl -fsSL -o "$tmp/dezog.vsix" "https://github.com/maziac/DeZog/releases/download/v$DEZOG_VER/dezog-$DEZOG_VER.vsix"
    echo "$DEZOG_SHA  $tmp/dezog.vsix" | sha256sum -c --status || { echo "Prüfsumme DeZog falsch" >&2; exit 1; }
    codium --install-extension "$tmp/dezog.vsix" >/dev/null 2>&1 && log "DeZog $DEZOG_VER installiert" || warn "DeZog nicht installierbar"
    rm -rf "$tmp"
  fi
fi

# Editor-Einstellungen (nur anlegen, wenn nicht vorhanden - eigene Änderungen bleiben)
cfg="$HOME/.config/VSCodium/User/settings.json"
mkdir -p "$(dirname "$cfg")"
[ -f "$cfg" ] || cat > "$cfg" <<'JSON'
{
  "telemetry.telemetryLevel": "off",
  "update.mode": "none",
  "workbench.startupEditor": "none",
  "editor.rulers": [80],
  "files.associations": { "*.z8a": "z80-macroasm", "*.asm": "z80-macroasm", "*.inc": "z80-macroasm" },
  "clangd.arguments": ["--header-insertion=never"]
}
JSON

log "user.sh fertig"
