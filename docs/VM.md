# VM „lab“ – Z80-Entwicklung (Labcomp)

Gebaut von **labortage26-z80env** · Debian 13 ARM64 · 3 CPUs, 4 GB RAM, 40 GB Platte (sparse) · Start: **StartLab** auf dem Mac-Schreibtisch

## Wofür
Entwicklungsumgebung für den Labcomp, einen Z80-Lernrechner (U880/Z80, Motif-Emulator, Monitor-Firmware). Der Emulator läuft in der VM,
Code wird in der IDE geschrieben, assembliert und im Emulator geladen. Details zur Hardware stehen im Projekt `labcomp`.

## Ordner in der VM (`~/Projects/labortage/`)
| Ordner | Inhalt |
|---|---|
| `labcomp/` | geklontes Projekt (Emulator, Firmware); Build mit `make` |
| `labortage26-z80env/` | das Skript-Repo, darin `examples/hello.z8a` |
| `code/` | Verknüpfung auf `~/LabShare/code` **auf dem Mac** – hier den eigenen Code ablegen |

IDE: Starter „Labcomp IDE“ öffnet `~/Lab.code-workspace` mit den drei Ordnern; **Strg+Shift+B** assembliert die offene `.z8a`-Datei.

## Werkzeuge
- **Z80/8080:** `sjasmplus`, `zmac` (George Phillips), `pasmo`, SDCC, **z88dk** v2.5 (inkl. zsdcc), `z80dasm`
- **Welches `z80asm`?** Drei Varianten, nichts davon überschreibt etwas anderes:
  - `z80asm` im PATH ist ein **Adapter**, der `sjasmplus` aufruft, damit das unveränderte Makefile die Firmware übersetzt.
  - `z80asm-git` (`/opt/z80asm-git/bin/z80asm`, nicht im PATH) ist das **echte `z80asm`** aus dem Git-Repository von Savannah (Stand 1.9, Commit `0df4a46`, 16.03.2021).
    Es versteht `inc ixl` & Co. und den unveränderten Makefile-Aufruf `z80asm -lfirmware.prn -o rom firmware.z8a`; die Firmware wird
    byte-identisch zum Adapter (3632 Byte). Benutzen: `PATH=/opt/z80asm-git/bin:$PATH make`.
  - `/usr/bin/z80asm` ist Debians Paket (Release 1.8 von 2009) und übersetzt die Firmware nicht (kennt `inc ixl` nicht).
  Außerdem liefert z88dk ein eigenes `z80asm` mit (ganz hinten im PATH); es übersetzt die Firmware erst ohne die letzte Zeile `end`.
- **Weitere:** `galasm` (GAL16V8), `avr-gcc`/`avrdude`, Logisim-evolution (Schaltplan), `picocom`/`minicom`, clangd, cppcheck
- **Debugger:** trszog (Fork von DeZog mit TRS-80-Simulator), ohne Zugriff auf das private Repo das Original-DeZog

## Eigenen Code laden und starten
1. Quelltext in `code/` schreiben, mit `sjasmplus --nologo --dirbol --raw=prog.bin prog.z8a` assemblieren; die Datei beginnt mit dem
   `recv`-Kopf (Zieladresse, Länge, dann Daten – siehe `examples/hello.z8a`; Programm ab `2000h`)
2. `./labcomp_emu -extmem 62256` (32 KB Erweiterungsspeicher ab `2000h`)
3. Taste **recv** → Menü **File → Receive from File…** → Datei wählen → Taste **go**

## Alltag
- Anzeigegröße: Starter „Anzeigegröße“ oder `labzoom normal|gross|riesig` (Standard: Groß)
- Abnahmetest jederzeit: `./05-test.sh` im Skript-Repo auf dem Mac
- Neu aufbauen: `./run-all.sh` im Repo `labortage26-z80env` (idempotent)
- KI-Werkzeuge: `claude`, `opencode`, `qwen` im Terminal; in der IDE Claude Code (Seitenleiste), Cline, Copilot Chat (Vorschläge aus)
