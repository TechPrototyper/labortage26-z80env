# labortage26-z80env

Wiederholbar aufgebaute **Z80-Entwicklungsumgebung für den Mac** (Apple Silicon): eine Debian-13-VM mit
Desktop, IDE und Toolchains, in der der **Labcomp-Emulator** (Z80-Lernrechner, Motif/X11) läuft.
Gedacht für die Labortage 26 – für alle, die einen Mac, aber keine Linux-Umgebung haben.

Kein XQuartz, keine VM-Lizenz: die VM läuft mit [Lima](https://lima-vm.io) auf Apples
Virtualization.framework (schnell, sparsam, Fenster direkt auf dem Mac).

Eine Kurzdoku der fertigen VM (Ordner, Werkzeuge, Alltag) steht in [`docs/VM.md`](docs/VM.md).

## Voraussetzungen

- Mac mit Apple Silicon, macOS 13 oder neuer
- [Homebrew](https://brew.sh)
- ca. 15 GB freier Speicher, Internetzugang
- Zeit: der erste Lauf dauert **ca. 40–60 Minuten** (davon etwa 20 für z88dk); jeder weitere Lauf nur wenige Minuten

## Los geht's

```bash
git clone https://github.com/TechPrototyper/labortage26-z80env.git
cd labortage26-z80env
./run-all.sh
```

Danach liegt **StartLab** auf dem Schreibtisch. Doppelklick startet die VM, es öffnet sich ein Fenster mit dem
Linux-Desktop (automatische Anmeldung). Auf dem VM-Desktop liegen Starter für Emulator, IDE, Logisim und Terminal.

`run-all.sh` ist **idempotent**: beliebig oft wiederholbar, es wird nur nachgeholt, was fehlt. Die Teilskripte
kann man auch einzeln aufrufen:

| Skript | Aufgabe |
|---|---|
| `01-host.sh` | Lima und ImageMagick per Homebrew installieren |
| `02-vm.sh` | Debian-Image laden (SHA-512 geprüft), VM anlegen und starten |
| `03-provision.sh` | Desktop, Toolchains, IDE und Erweiterungen in der VM einrichten |
| `04-repo.sh` | Verzeichnisstruktur `~/Projects/labortage/` in der VM einrichten (Labcomp-Projekt und dieses Repo klonen, `code/` auf den Mac-Ordner verknüpfen), Desktop-Starter anlegen |
| `05-test.sh` | Abnahmetest: Build, ROM, Toolchains, Emulator-GUI (inkl. Tastendruck) |
| `06-finish.sh` | VM herunterfahren, `StartLab.app` auf den Schreibtisch legen |

Einstellungen über Umgebungsvariablen: `VM_NAME` (Standard `lab`), `LABCOMP_REPO_URL` (Standard
`https://git.gay/ayron/labcomp`, z. B. für einen eigenen Fork), `LAB_CODE_DIR` (Mac-Ordner für eigenen Code, Standard `~/LabShare/code`), `TRSZOG=off` (Original-DeZog statt trszog),
`LAB_NO_STOP=1` (`06-finish.sh` lässt die VM laufen).

## Was installiert wird

- **System:** Debian 13 „trixie“ (ARM64) mit normalem Debian-Kernel, XFCE, deutsche Tastatur, Meldungen und Programme auf Englisch (`en_US.UTF-8`), Zahlen-/Datumsformat, Maßeinheiten und Papier deutsch (`LC_*=de_DE.UTF-8`), Zeitzone Berlin
- **IDE:** VSCodium (offizielles Repo des VSCodium-Projekts) mit Z80-Syntax, clangd, Hex-Editor, GitLens u. a.;
  Debugger **trszog** (Fork von DeZog, benötigt Zugriff auf `TechPrototyper/trszog`) – ohne Zugriff
  automatisch das Original **DeZog**
- **Z80/8080-Assembler und -Compiler:** `sjasmplus` (aus gepinnten Quellen), `zmac` (George Phillips, aus
  Quellen), `pasmo`, SDCC, **z88dk** v2.5 (aus Quellen, inkl. zsdcc), `z80dasm`
- **Browser:** Chromium (Debian), Standard-Browser. Google Chrome gibt es für Linux nur für x86_64, nicht für ARM64.
- **KI-Werkzeuge:** Claude Code (offizieller Installer), OpenCode und Qwen Code (npm, jeweils aktuelle Version bei jedem Lauf) sowie die
  VS-Code-Erweiterungen Claude Code, Cline, OpenCode, Qwen Code und GitHub Copilot Chat. **Standard ist Claude**: Claude Code öffnet in
  der Seitenleiste, Copilot-Vorschläge sind ausgeschaltet (`github.copilot.enable` einschaltbar). Es werden keine Zugangsdaten abgelegt;
  Anmeldung in der VM selbst (`claude`, `opencode auth login`, `qwen`, GitHub in der IDE).
- **Weitere:** `galasm` (GAL16V8), AVR-Toolchain (`avr-gcc`, `avrdude`), Logisim-evolution (Schaltplan),
  `picocom`/`minicom`, clangd, cppcheck, Motif-Entwicklungspakete

Von außen geladene Dateien (VM-Image, Logisim, VSIX, Quell-Commits) sind per Prüfsumme bzw. Commit-Hash gepinnt.

## Verzeichnisse und der erste eigene Code

In der VM liegt alles unter `~/Projects/labortage/`:

| Ordner | Inhalt |
|---|---|
| `labcomp/` | das geklonte Labcomp-Projekt (Emulator, Firmware) |
| `labortage26-z80env/` | dieses Repository, darin `examples/` mit Beispielen |
| `code/` | **Verknüpfung auf den Mac-Ordner `~/LabShare/code`** – hier liegt dein eigener Code |

Was in `code/` liegt, steht in Wahrheit auf dem Mac und bleibt erhalten, auch wenn die VM gelöscht und neu aufgebaut
wird (`LAB_CODE_DIR` ändert den Mac-Ordner). Alles andere in der VM ist ersetzbar. Beim ersten Lauf legt `04-repo.sh`
dort `hello.z8a` und einen Build-Task an; vorhandene Dateien werden nie überschrieben.

Der Labcomp hat 4 KiB ROM (Monitor ab `0000h`), 1 KiB RAM ab `1000h` und optional Erweiterungs-RAM. Mit
`./labcomp_emu -extmem 62256` liegen 32 KiB ab `2000h` bereit. [`examples/hello.z8a`](examples/hello.z8a) schreibt einen
Text auf das LCD und beginnt mit dem Kopf, den die `recv`-Funktion des Monitors erwartet (Zieladresse, Länge, Daten):

```bash
cd ~/Projects/labortage/code   # in der VM
sjasmplus --nologo --dirbol --raw=hello.bin hello.z8a
```

Die IDE-Starter öffnen den Workspace `~/Lab.code-workspace` mit den drei Ordnern `code`, `labcomp` und `labortage26-z80env` (das Skript-Repo samt `examples/`). In `code/`
baut **Strg+Shift+B** die gerade geöffnete `.z8a`-Datei mit sjasmplus (Fehler erscheinen im Problems-Panel).

Laden und starten im Emulator (so getestet, Programm läuft und schreibt „Hallo Labor!“ aufs LCD):

1. `./labcomp_emu -extmem 62256` im Ordner `labcomp/` starten
2. Taste **`recv`** drücken – der Monitor zeigt „receive“ und wartet
3. Menü **File → Receive from File…**, Pfad zu `hello.bin` eingeben (z. B. `/home/<benutzer>/Projects/labortage/code/hello.bin`), **Ok** (erst *nach* `recv`, sonst geht die Datei verloren)
4. Der Monitor zeigt den empfangenen Speicher ab `2000h`; Taste **`go`** startet das Programm

## Anzeigegröße (für gute Lesbarkeit)

Die VM startet in der Stufe **Groß** (1440×900, 144 dpi, größere Schrift, Panel und Symbole). Umstellen geht über den
Starter **„Anzeigegröße“** auf dem VM-Desktop oder im Terminal mit `labzoom normal|gross|riesig` (Auswahl wird gemerkt).
Bereits offene Programme (z. B. die IDE) danach neu starten. Kleiner Bildschirm (13") oder schwache Augen: `riesig`.
Die Editor-Schrift ist auf 15 pt gesetzt (`~/.config/VSCodium/User/settings.json`, eigene Werte bleiben erhalten);
die Vertrauensabfrage („Restricted Mode“) ist in der Lab-VM abgeschaltet.

## Bekannte Besonderheiten

- `firmware.z8a` nutzt Syntax (`ixl`/`ixh`, `add c`), die Debians `z80asm` nicht übersetzt. In der VM steht
  deshalb unter `/usr/local/bin/z80asm` ein kleiner Adapter, der `sjasmplus` aufruft, damit das unveränderte
  Makefile des Projekts läuft. z88dk liegt hinten im `PATH`, damit sein eigenes `z80asm` den Adapter nicht überdeckt.
- z88dk wird beim ersten Lauf aus den Quellen gebaut (ca. 20–30 Minuten); Standard-Backend ist `sccz80`, `zsdcc` ist ebenfalls dabei.
- Die VM bekommt 3 CPUs, 4 GB RAM und 40 GB (sparse) Platte – anpassbar in `lab.yaml` vor dem ersten Lauf.
- Dateien zwischen Mac und VM: `~/LabShare` auf dem Mac ist in der VM unter `/mnt/labshare` eingehängt.

## Welches z80asm?

`z80asm` im PATH ist ein Adapter, der `sjasmplus` aufruft. Als **Alternative** wird das echte `z80asm` aus dem Git-Repository von Savannah gebaut (`z80asm-git`,
Version 1.9 vom 16.03.2021, nie als Release erschienen): Es versteht den unveränderten Makefile-Aufruf und liefert dieselbe Firmware (3632 Byte). Aufruf:
`PATH=/opt/z80asm-git/bin:$PATH make`. Debians `z80asm` (Release 1.8 von 2009) übersetzt die Firmware nicht. Details: [`docs/VM.md`](docs/VM.md).

## Zurücksetzen

```bash
limactl delete --force lab    # VM löschen; danach ./run-all.sh baut sie neu
```

## Lizenz

Die Skripte in diesem Repository stehen unter der MIT-Lizenz (siehe `LICENSE`). Die installierten Programme
und das geklonte Labcomp-Projekt haben ihre jeweils eigenen Lizenzen.
