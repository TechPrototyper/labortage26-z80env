#!/usr/bin/env bash
# Als Benutzer: Claude Code, OpenCode, Qwen Code (jeweils aktuelle Version) und die VS-Code-Erweiterungen.
# Idempotent: bei jedem Lauf wird auf die jeweils neueste Version gebracht. Es werden KEINE Zugangsdaten
# abgelegt - Anmeldung später in der VM selbst (claude, opencode auth login, qwen).
set -euo pipefail
export LC_ALL=C.UTF-8
export PATH="/opt/node/bin:$HOME/.npm-global/bin:$HOME/.local/bin:$PATH"
log()  { printf '\033[1;34m  ->\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m  !!\033[0m %s\n' "$*" >&2; }

mkdir -p "$HOME/.npm-global"
npm config set prefix "$HOME/.npm-global" >/dev/null

# ---- Claude Code: offizieller (nativer) Installer von Anthropic, braucht kein Node
if command -v claude >/dev/null 2>&1; then
  log "Claude Code vorhanden ($(claude --version 2>/dev/null | head -1)), prüfe auf Update"
  timeout 180 claude update >/dev/null 2>&1 || warn "claude update nicht möglich (nicht kritisch)"
else
  log "Claude Code installieren (offizieller Installer)"
  curl -fsSL https://claude.ai/install.sh | bash >/dev/null 2>&1 || warn "Claude Code konnte nicht installiert werden"
fi

# ---- OpenCode und Qwen Code per npm (jeweils @latest, nur wenn nicht schon aktuell)
npm_latest() { # <paket>
  local pkg="$1" want have
  want="$(npm view "$pkg" version 2>/dev/null || true)"
  have="$(npm ls -g --depth=0 --json 2>/dev/null | python3 -c 'import sys,json; d=json.load(sys.stdin).get("dependencies",{}); print(d.get(sys.argv[1],{}).get("version",""))' "$pkg" 2>/dev/null || true)"
  if [ -n "$want" ] && [ "$have" = "$want" ]; then log "$pkg $have aktuell"; return; fi
  if npm install -g "$pkg@latest" >/dev/null 2>&1; then log "$pkg ${want:-?} installiert (vorher: ${have:-keine})"
  else warn "$pkg konnte nicht installiert werden"; fi
}
npm_latest opencode-ai
npm_latest @qwen-code/qwen-code

# ---- VS-Code-Erweiterungen (Open VSX); Rückfall auf direkten VSIX-Download für linux-arm64
installed="$(codium --list-extensions 2>/dev/null | tr 'A-Z' 'a-z' || true)"
ext() { # <namespace.name>
  if grep -qix "$(tr 'A-Z' 'a-z' <<<"$1")" <<<"$installed"; then log "Erweiterung $1 vorhanden"; return; fi
  if codium --install-extension "$1" >/dev/null 2>&1; then log "Erweiterung $1 installiert"; return; fi
  local ns="${1%%.*}" name="${1#*.}" url tmp
  for plat in linux-arm64 universal; do
    url="$(curl -fsS "https://open-vsx.org/api/$ns/$name/$plat/latest" 2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin)["files"]["download"])' 2>/dev/null || true)"
    [ -n "$url" ] || continue
    tmp="$(mktemp -d)"
    if curl -fsSL -o "$tmp/e.vsix" "$url" && codium --install-extension "$tmp/e.vsix" >/dev/null 2>&1; then
      log "Erweiterung $1 installiert (VSIX, $plat)"; rm -rf "$tmp"; return
    fi
    rm -rf "$tmp"
  done
  warn "Erweiterung $1 nicht installierbar (übersprungen)"
}
ext Anthropic.claude-code
ext sst-dev.opencode
ext qwenlm.qwen-code-vscode-ide-companion
ext saoudrizwan.claude-dev          # Cline

# ---- GitHub Copilot Chat: gibt es nicht auf Open VSX. Das Projekt ist MIT-lizenziert; das offizielle VSIX
# kommt aus dem GitHub-Release von microsoft/vscode-copilot-chat (SHA-256 gepinnt). Es nutzt "Proposed APIs",
# die für VSCodium in argv.json freigegeben werden. Anmeldung (GitHub-Konto mit Copilot) in der IDE.
COPILOT_VER=0.43.0
COPILOT_SHA=797dc8779ea3c4fa7ca470f40bc26f448a9d4d175cebe49cacfdf9872dfd9c1e
have_cp="$(codium --list-extensions --show-versions 2>/dev/null | grep -i '^github.copilot-chat@' | cut -d@ -f2 || true)"
if [ "$have_cp" = "$COPILOT_VER" ]; then
  log "GitHub Copilot Chat $COPILOT_VER vorhanden"
else
  tmp="$(mktemp -d)"
  if curl -fsSL -o "$tmp/cp.vsix" "https://github.com/microsoft/vscode-copilot-chat/releases/download/v$COPILOT_VER/GitHub.copilot-chat.$COPILOT_VER.universal.vsix" \
     && echo "$COPILOT_SHA  $tmp/cp.vsix" | sha256sum -c --status \
     && codium --install-extension "$tmp/cp.vsix" --force >/dev/null 2>&1; then
    log "GitHub Copilot Chat $COPILOT_VER installiert"
  else
    warn "GitHub Copilot Chat nicht installierbar (übersprungen)"
  fi
  rm -rf "$tmp"
fi
python3 - <<'PY'
import os, re
p = os.path.expanduser("~/.vscode-oss/argv.json")
t = open(p).read() if os.path.exists(p) else "{\n}\n"
if '"enable-proposed-api"' not in t:
    t = t.replace("{", '{\n\t"enable-proposed-api": ["GitHub.copilot-chat"],', 1)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, "w").write(t)
PY

# ---- Standard-Assistent: Claude. Claude Code öffnet in der Seitenleiste, Copilot-Vorschläge sind aus (jederzeit
# einschaltbar). Nur fehlende Schlüssel werden gesetzt, eigene Werte bleiben erhalten.
cfg="$HOME/.config/VSCodium/User/settings.json"
mkdir -p "$(dirname "$cfg")"; [ -f "$cfg" ] || echo '{}' > "$cfg"
python3 - "$cfg" <<'PY'
import json, sys
p = sys.argv[1]
d = json.load(open(p))
d.setdefault("claudeCode.preferredLocation", "sidebar")
d.setdefault("github.copilot.enable", {"*": False})
json.dump(d, open(p, "w"), indent=2, ensure_ascii=False)
PY

for c in claude opencode qwen; do
  v="$("$c" --version 2>/dev/null | head -1 || true)"; log "$c: ${v:-NICHT GEFUNDEN}"
done
