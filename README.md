# labortage26-z80env

Wiederholbar aufgebaute **Z80-Entwicklungsumgebung für den Mac** (Apple Silicon): eine Debian-13-VM mit
Desktop, IDE und Toolchains, in der der **Labcomp-Emulator** (Z80-Lernrechner, Motif/X11) läuft.
Gedacht für die Labortage 26 – für alle, die einen Mac, aber keine Linux-Umgebung haben.

Kein XQuartz, keine VM-Lizenz: die VM läuft mit [Lima](https://lima-vm.io) auf Apples
Virtualization.framework (schnell, sparsam, Fenster direkt auf dem Mac).

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
| `04-repo.sh` | Labcomp-Projekt nach `~/labcomp` in der VM klonen bzw. aktualisieren, Desktop-Starter anlegen |
| `05-test.sh` | Abnahmetest: Build, ROM, Toolchains, Emulator-GUI (inkl. Tastendruck) |
| `06-finish.sh` | VM herunterfahren, `StartLab.app` auf den Schreibtisch legen |

Einstellungen über Umgebungsvariablen: `VM_NAME` (Standard `lab`), `LABCOMP_REPO_URL` (Standard
`https://git.gay/ayron/labcomp`, z. B. für einen eigenen Fork), `TRSZOG=off` (Original-DeZog statt trszog),
`LAB_NO_STOP=1` (`06-finish.sh` lässt die VM laufen).

## Was installiert wird

- **System:** Debian 13 „trixie“ (ARM64) mit normalem Debian-Kernel, XFCE, deutsche Tastatur/Locale, Zeitzone Berlin
- **IDE:** VSCodium (offizielles Repo des VSCodium-Projekts) mit Z80-Syntax, clangd, Hex-Editor, GitLens u. a.;
  Debugger **trszog** (Fork von DeZog, benötigt Zugriff auf `TechPrototyper/trszog`) – ohne Zugriff
  automatisch das Original **DeZog**
- **Z80/8080-Assembler und -Compiler:** `sjasmplus` (aus gepinnten Quellen), `zmac` (George Phillips, aus
  Quellen), `pasmo`, SDCC, **z88dk** v2.5 (aus Quellen, ohne zsdcc), `z80dasm`
- **Weitere:** `galasm` (GAL16V8), AVR-Toolchain (`avr-gcc`, `avrdude`), Logisim-evolution (Schaltplan),
  `picocom`/`minicom`, clangd, cppcheck, Motif-Entwicklungspakete

Von außen geladene Dateien (VM-Image, Logisim, VSIX, Quell-Commits) sind per Prüfsumme bzw. Commit-Hash gepinnt.

## Der erste eigene Code

Der Labcomp hat 4 KiB ROM (Monitor ab `0000h`), 1 KiB RAM ab `1000h` und optional Erweiterungs-RAM. Mit
`./labcomp_emu -extmem 62256` liegen 32 KiB ab `2000h` bereit. Das Beispiel in
[`examples/hello.z8a`](examples/hello.z8a) schreibt einen Text auf das LCD und beginnt mit dem Kopf, den die
`recv`-Funktion des Monitors erwartet (Zieladresse, Länge, Daten):

Die Beispiele liegen in diesem Repo im Ordner `examples/` und werden von `04-repo.sh` in die VM nach `~/examples` kopiert:

```bash
cd ~/examples   # in der VM
sjasmplus --nologo --dirbol --raw=hello.bin hello.z8a
```

Laden und starten im Emulator (so getestet, Programm läuft und schreibt „Hallo Labor!“ aufs LCD):

1. `./labcomp_emu -extmem 62256` starten
2. Taste **`recv`** drücken – der Monitor zeigt „receive“ und wartet
3. Menü **File → Receive from File…**, Pfad zu `hello.bin` eingeben, **Ok** (erst *nach* `recv`, sonst geht die Datei verloren)
4. Der Monitor zeigt den empfangenen Speicher ab `2000h`; Taste **`go`** startet das Programm

## Bekannte Besonderheiten

- `firmware.z8a` nutzt Syntax (`ixl`/`ixh`, `add c`), die Debians `z80asm` nicht übersetzt. In der VM steht
  deshalb unter `/usr/local/bin/z80asm` ein kleiner Adapter, der `sjasmplus` aufruft, damit das unveränderte
  Makefile des Projekts läuft. z88dk liegt hinten im `PATH`, damit sein eigenes `z80asm` den Adapter nicht überdeckt.
- Das Standard-Compiler-Backend von z88dk ist `sccz80`; `zsdcc` wird nicht mitgebaut.
- Die VM bekommt 3 CPUs, 4 GB RAM und 40 GB (sparse) Platte – anpassbar in `lab.yaml` vor dem ersten Lauf.
- Dateien zwischen Mac und VM: `~/LabShare` auf dem Mac ist in der VM unter `/mnt/labshare` eingehängt.

## Zurücksetzen

```bash
limactl delete --force lab    # VM löschen; danach ./run-all.sh baut sie neu
```

## Lizenz

Die Skripte in diesem Repository stehen unter der MIT-Lizenz (siehe `LICENSE`). Die installierten Programme
und das geklonte Labcomp-Projekt haben ihre jeweils eigenen Lizenzen.
