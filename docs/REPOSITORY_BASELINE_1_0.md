# Repository Baseline 1.0 – Sicherung und Konsistenz

Stand: 2026-10-30. Sicherungs- und Integrationsauftrag, kein Refactoring: Der persönlich abgenommene Spielstand,
der bis dahin teilweise nur im Arbeitsbaum lag, ist jetzt vollständig versioniert. Es wurden keine Inhalte
geändert, nur gesichert, gezielt gestagt und committet.

## 1. Sicherung

Ort (außerhalb des Repositorys): `C:\Users\ncbha\GameDev\backups\echo_baseline_2026-10-30_1100\`

| Datei | Inhalt |
|---|---|
| `HEAD.txt` | HEAD `2a4d805d0136d55d9eb91f637b9395fc50acf02b`, Branch `dev/roots-remember-m4` |
| `status.txt` | `git status --porcelain --untracked-files=all` (530 Einträge) |
| `staged.patch` | gestagte Änderungen, binär (leer: zu Beginn war nichts gestagt) |
| `unstaged.patch` | `git diff --binary` aller 106 geänderten und 3 gelöschten Dateien; `git apply --check --cached` gegen HEAD: OK |
| `modified_raw.tar` | die 106 geänderten Dateien byte-genau (mit CRLF, da `core.autocrlf=true` den Patch normalisiert) |
| `untracked.tar` | alle 421 ungetrackten, nicht ignorierten Dateien (inkl. `docs/Design/`, `docs/tasks/`) |
| `MANIFEST.txt` | SHA-256 und Pfad jeder gesicherten Datei, Liste der Löschungen |
| `CHECKSUMS.sha256` | Prüfsummen der Sicherungsdateien |

Prüfung: beide Archive in einen getrennten Ordner entpackt, alle 527 SHA-256-Werte stimmen mit dem Manifest überein.
Nicht gesichert (bewusst): `.godot/`, `tests/output/` (generiert, ignoriert), `user://` (Spielstände,
`settings.cfg`). Vor dem Staging wurde der Inhalt auf Zugangsdaten, Schlüssel und Benutzerpfade durchsucht: kein
Fund.

## 2. Branch und HEAD

| | Wert |
|---|---|
| Branch | `dev/roots-remember-m4` (unverändert) |
| HEAD vorher | `2a4d805` – docs: inventory save/load roundtrip 1.0 - commit hash |
| HEAD nach den Baseline-Commits | `867376b` (dieses Dokument folgt als ein letzter Commit) |

Exklusivität: Die einzige weitere Claude-Sitzung (Inventory-Roundtrip) war idle und hatte ihre Arbeit committet
(`b98c662`, `2a4d805`). Der Godot-Editor des Entwicklers lief seit dem 29.10.; in den 30 Minuten vor Beginn hat er
keine Projektdateien geschrieben. Bei Beginn war nichts gestagt.

## 3. Aufgenommene Komponenten

| Commit | Inhalt |
|---|---|
| `0662588` | **UI-Assets und Schriften:** 128 bisher ungetrackte UI-PNGs mit `.import` (zusammen mit den 8 schon getrackten HUD-PNGs genau die 136, die der Validator erwartet), `assets/fonts/ibm_plex_mono` und `assets/fonts/silkscreen` je mit Schrift, `.import` und `OFL.txt` |
| `24972f7` | **Generator und Validator:** `tools/ui_art/generate_core_ui_assets.py`, `validate_ui_assets.py` (Python 3 + Pillow) |
| `bf721a2` | **Produktiver Code, Daten und Szenen:** 68 geänderte Dateien unter `scripts/`, `data/`, `scenes/`, `localization/ui.csv`; neu: `UiSkin`, `ComboIcons`, `HudXpBar`, `HudSlot`, `HudMenuBar`, `BarText`, `SplitBarText`, `AreaMinimap`, `MapPainter`, `AreaMap`, `MapFog`, `MapMarkers`, `MapLandmark` (je mit `.uid`); drei Nebenquest-Daten unter `data/story/`; Löschung von `scripts/ui/hud/player_frame.gd` (+ `.uid`), ersetzt durch `HudVessel` (Combat HUD UX 2.0), keine Code-Referenz mehr |
| `86e3730` | **Tests:** 24 geänderte und 26 neue Integrations-Suites plus 1 neue Unit-Suite (mit `.uid`), 5 geänderte Playtests/Galerie, `ui_art_check.gd`, fehlende `roots_m4_visual_check.gd.uid`; Löschung von `test_grove_warden_reward.gd`, ersetzt durch `test_chapter_1_rare_reward.gd` (laut `CHAPTER_1_RARE_REWARD_1_0.md`) |
| `781fc94` | **Entwicklermaterial Schriftauswahl:** `assets/fonts/candidates/` (`.gdignore`, nie importiert, jede Schrift mit Lizenzdatei), `tests/playtest/font_preview.gd`, `bdf_font.gd` |
| `867376b` | **Dokumentation:** 29 neue Batch-Dokumente, `CHATGPT_PROJECT_HANDOFF.md`, 7 geänderte Systemdokumente, `CLAUDE.md` |

Hinweis zu Zeilenenden: `core.autocrlf=true` speichert 12 CRLF-Dateien beim Commit mit LF (Git-Standardverhalten
dieses Repos, keine eigene Normalisierung; die Arbeitskopien bleiben unverändert).

Die Commitfolge ist erst als Ganzes konsistent: Zwischenstände (z. B. nach `0662588`) erben die bekannte
Inkonsistenz des alten HEAD (committete HUD-Teile ohne ihre Abhängigkeiten).

## 4. Isolierte Prüfung des committeten Stands

Prüfausgabe: `git archive HEAD` (bei `867376b`) in einen leeren Ordner im Scratchpad entpackt, außerhalb des
Repositorys; 1877 Dateien = `git ls-files`, kein `.godot/`, keine ungetrackten Dateien. Engine über
`$env:GODOT` (`..\tools\godot\Godot_v4.7.2-stable_win64_console.exe`, absolut). Kein Checkout, kein Worktree.

| Prüfung | Ergebnis |
|---|---|
| `tools/check_project.ps1`, 1. Lauf (allererster Import) | **Fehlgeschlagen:** `Cannot open file 'res://localization/ui.en.translation'` (2×). Die Datei ist per `.gitignore` (`*.translation`) bewusst nicht versioniert und entsteht erst beim Import von `ui.csv`; beim ersten Import wird sie geladen, bevor sie existiert |
| `tools/check_project.ps1`, 2. Lauf | **OK** (Import + 300 Frames der Hauptszene, keine Fehler, keine Warnungen) |
| `run_tests.ps1 -Suite "combat_hud,map_ux,loot_progress_feedback,parry_timing_cue"` | **24 bestanden, 0 fehlgeschlagen** |
| `py -3 tools/ui_art/validate_ui_assets.py` | **RESULT: OK** |
| Generator `generate_core_ui_assets.py --force` in der Prüfausgabe | alle 136 PNGs **byte-identisch** neu erzeugt |
| `project.godot` HEAD vs. Arbeitsbaum über die Engine ausgelesen | identische Werte (siehe 6) |

Nicht ausgeführt: Full-Suite, Gameplay-Loops, Screenshot-/Skalierungsmatrix (nicht beauftragt). Die Tests schreiben
nur nach `user://test_saves/`; die Prüfausgabe teilt sich wegen gleichen Projektnamens den `user://`-Ordner mit dem
echten Projekt, echte Spielstände wurden nicht verwendet.

## 5. Verbleibende Unterschiede im Arbeitsbaum

| Datei | Grund |
|---|---|
| `M project.godot` | Schutzdatei; nicht committet, Entscheidung offen (siehe 6). Wirkungsgleich mit HEAD |
| `?? docs/Design/WEAPON_MASTERY_COMBAT_FLOW_1_4_1_5.md` | geschützte Spezifikation; nur gesichert, nicht gestagt |
| `?? docs/tasks/OVERNIGHT_ARTISAN_CRAFTING_01.md` | geschützter Arbeitsauftrag; nur gesichert, nicht gestagt |

Weiter bestehend, unverändert übernommen (gehört nicht zu dieser Sicherung): die getrackte, verwaiste
`tests/integration/test_grove_warden_reward.gd.uid` (die `.gd` ist gelöscht). Sie wurde nicht auf Verdacht entfernt.

## 6. Offene Entscheidungen

**`project.godot`:** exakter Diff gegenüber HEAD:

```diff
@@ -31,7 +31,6 @@ window/size/viewport_height=1080
 window/size/window_width_override=1600
 window/size/window_height_override=900
 window/stretch/mode="canvas_items"
-window/stretch/aspect="keep"

 [input]

@@ -181,6 +180,10 @@ toggle_fullscreen={
 ]
 }

+[internationalization]
+
+locale/translations=PackedStringArray("res://localization/ui.en.translation")
+
 [layer_names]

 2d_physics/layer_1="world"
@@ -192,8 +195,3 @@ toggle_fullscreen={

 textures/canvas_textures/default_texture_filter=0
 environment/defaults/default_clear_color=Color(0.05, 0.045, 0.07, 1)
-
-[internationalization]
-
-locale/translations=PackedStringArray("res://localization/ui.en.translation")
-locale/fallback="en"
```

Mit Godot 4.7.2 ausgelesen (beide Fassungen): `stretch/aspect = keep` (Standard `keep`), `stretch/mode =
canvas_items`, `locale/fallback = en` (Standard `en`), `locale/translations` gleich. Die Änderungen entsprechen dem
Speichern durch den Editor (Standardwerte werden weggelassen, Abschnitte alphabetisch sortiert): **äquivalent,
nicht erforderlich, nicht verhaltensändernd.** Empfehlung: committen *oder* verwerfen ist gleichwertig; die explizite
Fassung in HEAD ist robuster, falls sich ein Standardwert in einer späteren Engine-Version ändert. Der Editor wird
die Kurzfassung beim nächsten Speichern der Projekteinstellungen wieder schreiben – Entscheidung des Entwicklers.

**Erster Import:** behoben durch Fresh Import Reliability 1.0 (`docs/FRESH_IMPORT_RELIABILITY_1_0.md`):
`check_project.ps1` erzeugt fehlende CSV-Übersetzungen in einer eigenen, streng geprüften Vorbereitungsphase und
erkennt Problemzeilen case-sensitiv. Der erste Lauf auf einer frischen Ausgabe ist erfolgreich.

**`docs/Design/`, `docs/tasks/`:** ob diese Spezifikationen versioniert werden sollen, entscheidet der Entwickler.

**`test_grove_warden_reward.gd.uid`:** mit der nächsten Bereinigung entfernen oder behalten.

## 7. Aussage zur Reproduzierbarkeit

Ein frischer Stand aus Git (`867376b` und folgende) bildet den abgenommenen Spielstand ab: Alle produktiven Quellen,
Daten, Szenen, UI-Assets, Schriften, Lizenzen, Generator und Validator sind versioniert. Die verbleibende
`project.godot`-Abweichung ist laut Engine wirkungsgleich. Der Generator erzeugt die Assets byte-identisch neu.
Der Translation-Fehler des allerersten Imports aus Abschnitt 4 ist seit Fresh Import Reliability 1.0 behoben:
Der erste `check_project.ps1`-Lauf auf einer frischen Ausgabe ist erfolgreich. Die gezielten Suites und der
Validator sind grün. Nicht geprüft sind die Full-Suite und
die Gameplay-Loops; die bekannten veralteten Tests (rpg_playtest, test_prologue v3→v4, test_ui_layout 150 %,
prologue_playtest) wurden unverändert übernommen.
