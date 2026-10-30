# Fresh Import Reliability 1.0

Stand: 2026-10-30. Ziel: Ein frisch aus Git exportierter Projektstand besteht schon seinen **ersten**
`tools/check_project.ps1`-Lauf. Keine Änderung an Gameplay, Save v15, UI, Texten oder `project.godot`.

## 1. Reproduzierte Ursache

Frische Ausgabe von `git archive HEAD` (`0105831`), ohne `.godot/` und ohne `*.translation`, darin ein einzelner
`--headless --import`-Lauf mit vollständigem Log. Es gab zwei getrennte Ursachen, beide nur beim Erstimport:

1. **Engine-Start vor dem Import (Importphase, kein Script-Fehler):** `project.godot` listet unter
   `internationalization/locale/translations` die Datei `res://localization/ui.en.translation`. Diese Datei ist die
   Ausgabe des CSV-Imports von `localization/ui.csv` (`ui.csv.import`: `importer="csv_translation"`,
   `dest_files=["res://localization/ui.en.translation"]`) und per `.gitignore` (`*.translation`) bewusst nicht
   versioniert. Godot lädt die gelisteten Übersetzungen beim Start (Log-Zeilen 2–9, also **vor**
   `first_scan_filesystem`), und erst danach erzeugt derselbe Lauf die Datei. Das ergibt je 2 Meldungen, zweimal:
   `ERROR: Cannot open file 'res://localization/ui.en.translation'.` und
   `ERROR: Failed loading resource: res://localization/ui.en.translation.`
   Nach dem Lauf existiert die Datei; das Spiel und die Startphase (300 Frames) sind fehlerfrei.
2. **Falscher Treffer im Prüfskript (Fehler der Startprüfung):** `check_project.ps1` filterte mit `-match "ERROR|…"`,
   in PowerShell ohne Beachtung der Groß-/Kleinschreibung. Der erste Scan schreibt die Fortschrittszeile
   `[  63% ] update_scripts_classes | TestErrorCounter` (Klassenname aus `tests/framework/error_counter.gd`). Sie wurde
   als Problem gezählt. Diese Zeile erscheint nur beim Aufbau des Klassen-Caches, also nur beim Erstimport. Auch
   ohne Ursache 1 wäre der erste Lauf daran gescheitert.

Der Scriptstand selbst war fehlerfrei: keine Parse- oder Laufzeitfehler.

## 2. Gewählte Korrektur (nur `tools/check_project.ps1`)

- **Phase 0 – Importvorbereitung, nur bei Bedarf.** Das Skript ermittelt die Übersetzungen, die
  `project.godot` listet, die auf der Platte fehlen **und** die ein `*.csv.import` mit `importer="csv_translation"`
  als `dest_files` erzeugt. Nur wenn es solche gibt (frischer Stand), läuft genau ein vorbereitender
  `--headless --import`. In diesem Lauf sind ausschließlich die zwei vorhersagbaren Zeilen pro fehlender Datei
  erlaubt, als exakter Textvergleich. Jede andere Fehler- oder Warnzeile, oder eine danach immer noch fehlende
  Datei, beendet die Prüfung mit `Import preparation failed` und Exit 1. Bei Erfolg meldet das Skript
  `Import preparation: generated <Pfad>`.
- **Phasen 1–2 unverändert:** voller Import, danach 300 Frames der Hauptszene; jede Problemzeile führt zum
  Fehlschlag. Es gibt keine Wiederholung und keine Ausnahmen.
- **Problemerkennung case-sensitiv** (`-cmatch "ERROR|Parse Error|WARNING:"`, gemeinsam in `Get-Problems`). Godot
  schreibt `ERROR:`, `SCRIPT ERROR:`, `WARNING:` immer in Großbuchstaben; Klassennamen wie `TestErrorCounter` treffen
  nicht mehr.

Verworfen:
- Die generierte `.translation` versionieren: verdeckt nur die Pipeline.
- Ein temporäres `override.cfg` mit leerer Übersetzungsliste: Ein abgebrochener Lauf hätte das Spiel still ohne
  Übersetzungen hinterlassen.
- Laden der Übersetzung im Code statt über `project.godot`: Das würde die geschützte `project.godot` und die
  Lokalisierung ändern.

`project.godot` musste nicht geändert werden. Die vorhandene lokale Änderung daran bleibt unangetastet.

## 3. Aufbau der frischen Prüfausgabe

1. Neuer leerer Ordner im Scratchpad (außerhalb des Repositorys).
2. `git archive HEAD | tar -x` (HEAD `0105831`). Danach nur `tools/check_project.ps1` aus dem Arbeitsbaum
   darübergelegt (die zu prüfende Korrektur). `project.godot` ist identisch mit HEAD; es gibt kein `.godot/` und
   keine `*.translation`.
3. Engine über `$env:GODOT` (`Godot_v4.7.2-stable_win64_console.exe`, absolut).

Der aktive Arbeitsbaum und sein `.godot`-Cache wurden nicht verändert. Es wurden keine echten Spielstände benutzt.

## 4. Ergebnisse

| Lauf | Ergebnis |
|---|---|
| Reproduktion: alter Import auf frischer Ausgabe | 4 `ERROR`-Zeilen zur fehlenden `ui.en.translation` vor `first_scan_filesystem`, dazu die Zeile `TestErrorCounter` |
| **1. Lauf `check_project.ps1` auf frischer Ausgabe** | `Import preparation: generated res://localization/ui.en.translation.` → `Startup check OK`, **Exit 0** |
| Übersetzungen danach | `ui.en.translation` vorhanden; Probe-Skript: `tr("UI_PROLOGUE")` = „Prologue“, `UI_TRIAL_CLASS` und `UI_LEAVE_TRIAL_HINT` aufgelöst, geladene Locales `["en"]` |
| 2. normaler Lauf | ohne Vorbereitungsphase `Startup check OK`, **Exit 0** |
| Gegenprobe: frische Ausgabe mit Parse-Fehler in `scripts/ui/title_screen.gd` | `Import preparation failed` mit `SCRIPT ERROR: Parse Error…` und `Failed to load script…`, **Exit 1** |

Eine erste Gegenprobe mit einem nirgends verwendeten, defekten Skript lief grün durch. Godot parst unreferenzierte
Skripte beim Import nicht, und das alte Skript hätte sie genauso wenig gefunden. Das ist keine Änderung durch
diese Korrektur, aber eine bestehende Grenze der Startprüfung.

Nicht ausgeführt: Testsuites (die Korrektur betrifft nur das Prüfskript), Full-Suite, Gameplay-Loops, Screenshots.

## 5. Verbleibende Einschränkungen

- `check_project.ps1` findet nur Fehler in Skripten, die Import oder Hauptszene tatsächlich laden.
  Unreferenzierte Skripte decken die Testsuites ab.
- `run_tests.ps1` verwirft die Ausgabe seines Imports (`| Out-Null`); dort war der Erstimport nie ein
  Fehlschlag, und das Skript wurde nicht geändert.
- Die Vorbereitungsphase kennt nur generierte CSV-Übersetzungen. Andere Ressourcen, die `project.godot` beim Start
  lädt und die erst ein Import erzeugt, gibt es derzeit nicht.

## 6. Geänderte Dateien

- `tools/check_project.ps1`: Phase 0, `Get-Problems` (case-sensitiv), Hilfsfunktionen.
- `docs/FRESH_IMPORT_RELIABILITY_1_0.md` (neu).
- `docs/REPOSITORY_BASELINE_1_0.md`: Einschränkungshinweis zum Erstimport aktualisiert.
