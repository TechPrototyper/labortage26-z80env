#!/usr/bin/env bash
# e) Abnahmetest in der VM. Bricht beim ersten Fehler mit Exit-Code != 0 ab.
set -euo pipefail
cd "$HOME/labcomp"
pass() { printf '\033[1;32m  PASS\033[0m %s\n' "$*"; }
fail() { printf '\033[1;31m  FAIL\033[0m %s\n' "$*"; exit 1; }

# 1. Clean build des Emulators und der Firmware
make clean >/dev/null
make >build.log 2>&1 || { tail -30 build.log; fail "make"; }
[ -x labcomp_emu ] && pass "labcomp_emu gebaut" || fail "labcomp_emu fehlt"
[ -s rom ] && pass "ROM assembliert ($(stat -c %s rom) Byte)" || fail "rom fehlt"
[ "$(stat -c %s rom)" -le 4096 ] && pass "ROM passt in 4 KiB" || fail "ROM größer als 4 KiB"

# 2. ROM ist gültiger Z80-Code: Reset-Vektor disassemblieren
dis="$(z80dasm -g 0 rom 2>/dev/null)"
grep -qE '^[[:space:]]+(ld|jp|jr|di|im)[[:space:]]' <<<"$dis" \
  && pass "ROM disassembliert sinnvoll (Reset-Vektor)" || fail "ROM-Disassembly"

# 3. Weitere Toolchains
[ "$(command -v z80asm)" = /usr/local/bin/z80asm ] && pass "z80asm-Adapter (sjasmplus)" || fail "z80asm-Adapter"
sjasmplus --version >/dev/null 2>&1 && pass "sjasmplus" || fail "sjasmplus"
sdcc --version >/dev/null 2>&1 && pass "sdcc" || fail "sdcc"
galasm -h >/dev/null 2>&1 || galasm 2>&1 | grep -qi galasm && pass "galasm" || fail "galasm"
avr-gcc --version >/dev/null && pass "avr-gcc" || fail "avr-gcc"
codium --version >/dev/null 2>&1 && pass "VSCodium $(codium --version 2>/dev/null | head -1)" || fail "codium"
codium --list-extensions 2>/dev/null | grep -qix mborik.z80-macroasm && pass "Erweiterung z80-macroasm" || fail "Erweiterung z80-macroasm"
if [ -f /tmp/trszog.vsix ]; then
  codium --list-extensions --show-versions 2>/dev/null | grep -qiE '^techprototyper\.dezog@.*trs80' \
    && pass "trszog installiert ($(codium --list-extensions --show-versions 2>/dev/null | grep -i '^techprototyper.dezog@'))" || fail "trszog"
else
  codium --list-extensions 2>/dev/null | grep -qix maziac.dezog && pass "DeZog (Original) installiert" || fail "DeZog"
fi
# Werkzeuge
. /etc/profile.d/z88dk.sh
zmac --version 2>&1 | grep -q 18oct2022 && pass "zmac $(zmac --version 2>&1 | head -1)" || fail "zmac"
clangd --version >/dev/null 2>&1 && pass "clangd" || fail "clangd"
cppcheck --version >/dev/null 2>&1 && pass "cppcheck $(cppcheck --version)" || fail "cppcheck"
[ -f /opt/logisim-evolution/logisim-evolution-5.0.0-all.jar ] && java -version >/dev/null 2>&1 && pass "Logisim + Java" || fail "Logisim"

# 3b. z88dk: C- und Assembler-Beispiel für TRS-80 und generisches Z80 übersetzen, zmac mit -j (wie trszog)
tdir="$(mktemp -d)"
cat > "$tdir/hello.c" <<'C'
#include <stdio.h>
int main(void) { puts("Hallo Labor"); return 0; }
C
(cd "$tdir" && zcc +trs80 -create-app hello.c -o hello >/dev/null 2>&1) && [ -s "$tdir/hello.cas" ] \
  && pass "z88dk: C-Programm für TRS-80 übersetzt" || fail "z88dk +trs80"
(cd "$tdir" && zcc +z80 -startup=0 -clib=classic hello.c -o hello_z80.bin >/dev/null 2>&1) && pass "z88dk: +z80 Target" || fail "z88dk +z80"
printf '\torg 5200h\nstart:\tld a,1\n\tret\n\tend start\n' > "$tdir/t.asm"
(cd "$tdir" && zmac -j t.asm >/dev/null 2>&1) && [ -s "$tdir/zout/t.cmd" ] && [ -s "$tdir/zout/t.bds" ] \
  && pass "zmac -j erzeugt .cmd und .bds" || fail "zmac -j"
rm -rf "$tdir"

# 3c. Beispiel aus ~/examples assemblieren (26 Byte: 4 Byte recv-Kopf + 22 Byte Programm)
tdir2="$(mktemp -d)"
(cd "$HOME/examples" && sjasmplus --nologo --dirbol --raw="$tdir2/hello.bin" hello.z8a >/dev/null 2>&1) \
  && [ "$(stat -c %s "$tdir2/hello.bin")" = 26 ] && pass "Beispiel hello.z8a assembliert (26 Byte)" || fail "Beispiel hello.z8a"
[ -f "$HOME/Lab.code-workspace" ] && pass "Workspace-Datei vorhanden" || fail "Workspace-Datei"
rm -rf "$tdir2"

zoom_out="$("$HOME/.local/bin/labzoom" bogus 2>&1 || true)"
grep -q usage <<<"$zoom_out" && pass "labzoom vorhanden" || fail "labzoom"

# 4. Emulator startet unter virtuellem X-Server, läuft stabil und reagiert auf Tastendruck:
#    LCD-Ausschnitt vor/nach Klick auf "PC" muss sich unterscheiden (Firmware läuft im Emulator).
cat > /tmp/emu-ui-test.sh <<'UI'
set -e
cd "$HOME/labcomp"
./labcomp_emu >emu.log 2>&1 & pid=$!
trap 'kill $pid 2>/dev/null || true' EXIT
sleep 5
kill -0 $pid || { echo "Emulator beendet"; cat emu.log; exit 2; }
xwininfo -root -tree | grep -qi "labcomp\|emulator" || { echo "kein Fenster"; exit 3; }
import -window root -crop 140x70+250+45 +repage /tmp/lcd-before.png
xdotool mousemove 219 179 click 1; sleep 2
import -window root -crop 140x70+250+45 +repage /tmp/lcd-after.png
import -window root /tmp/lab-emu.png
diff_px="$(compare -metric AE /tmp/lcd-before.png /tmp/lcd-after.png null: 2>&1 || true)"
echo "LCD geänderte Pixel: $diff_px"
[ "${diff_px%%.*}" -gt 0 ]
UI
xvfb-run -a -s '-screen 0 1280x900x24' bash /tmp/emu-ui-test.sh \
  && pass "Emulator läuft, zeigt Fenster, LCD reagiert auf Tastendruck" || fail "Emulator-GUI-Test"
echo "Alle Tests bestanden."
