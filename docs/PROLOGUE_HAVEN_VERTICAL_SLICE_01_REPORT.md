# Prologue & Haven Vertical Slice 0.1 – Bericht

Branch `dev/prologue-haven-slice-01` (abgezweigt von `9f134b9`). Kein Push.
Design: `PROLOGUE_AND_HAVEN.md`. Saves: `SAVE_SYSTEM.md`.

## Commits
| Phase | Commit | Inhalt |
|---|---|---|
| A | `bfa3829` | Save Foundation 1.1: 5 Slots, 3 rotierende Autosaves, Queue, Meilenstein-Saves, Anzeige, Titel- und Pausemenü, Save v5 |
| B | `9488169` | Story-Quests (Schritte, Event-Ziele), 5 Prolog-Quests und Hauptquest-Stub, Flags, Tod im Trial |
| C | `9176685` | Old Road, Mara (Dialog, Bark, Kampfhilfe, Eskorte), Begegnungen, Gegnervarianten, Kisten, Hinweise |
| D | `3e11dac` | Haven mit sechs Ruinen, atomare Restaurierung, „A Fire Rekindled“, Old Storehouse, Mara und Edrin, Nordtor |
| E | `dd0f6c4` | Whispering Stone, drei Echos, Klassenwahl (Erfolg erst nach Save), Wegsteine, Rückkehr, Hauptquest |
| F | (dieser Commit) | Integration: Save/Load-Zyklen im Fensterlauf, UI 1080p/4K bei 100/150 %, Doku |

**Fremde Änderung in `project.godot`:**
- Diese Hunks wurden weder überschrieben noch mitcommittet: `stretch/aspect` entfernt,
  `[internationalization]` verschoben, `locale/fallback` entfernt.
- Committet wurde nur die Zeile `run/main_scene`, auf den Titelbildschirm umgestellt. Dafür wurde ein Blob
  aus `HEAD:project.godot` mit genau dieser Änderung gestaged.
- Die Arbeitskopie enthält die fremden Hunks weiterhin unverändert.

## Testergebnisse (tatsächlich gelaufen)
- **Volle Suite am Ende: 421 / 421 bestanden, 56 Suites** (`./tools/run_tests.ps1`, Log
  `tests/output/full_suite.log`). Darin laufen alle Combat-Suites unverändert grün mit; es gibt keine
  Combat-Regression. Timings, Dash, Combos, Defense und Focus 6/s wurden nicht angefasst.
- Neue Suites:

  | Suite | Tests |
  |---|---|
  | `save_foundation` | 11 |
  | `story` | 9 |
  | `old_road` | 7 |
  | `haven` | 7 |
  | `shrine` | 6 |

- Angepasste Suites (Haven hat keine Bauplätze mehr, Titel ist Hauptszene, Version 5):
  - `base`, `loop`, `crafting_loop`, `ui_layout`: arbeiten jetzt auf den Ruinen
  - `world`: Kartenanzahl wird aus den Daten abgeleitet
  - `prologue`: prüft Version ≥ 4
- Startprüfung `./tools/check_project.ps1`: OK nach jeder Phase.

### Startprüfung & Fensterläufe
- **`prologue_playtest.gd` (echtes Fenster, `--fixed-fps 60`): RESULT OK, 0 fehlgeschlagene Checks.**
  - Titel → New Game → Old Road (Signpost, Hinterhalt, Rastplatz, Seitenweg mit Notiz und Ressourcen,
    Wagenkampf mit Maras Hilfe, Gespräch, 2 Kisten, zweite Welle, Eskorte)
  - Haven (Willkommen, nicht verfügbare Ruine, A Fire Rekindled, Forge, Old Storehouse, Edrin)
  - Whispering Stone (Pfadkampf, Memory Fragment, drei Echos in echtem Kampf mit Klassenskills; im
    Arcanist-Echo ist der Bot einmal gestorben und hat das Echo sauber neu gestartet)
  - Klassenwahl (Shadowrunner), Wegstein-Erweckung, Schnellreise nach Haven, Mara und Edrin, Prolog
    abgeschlossen, Hauptquest aktiv
  - Gesteuert nur über Bewegung, Zielen, LMB/Skills und echte G-/Esc-Events. **Kein F4/F6/F9/F10.**
  - Drei **Save/Load-Zyklen über das Pausemenü** (Haven-Ankunft, Whispering Stone, nach der Wahl):
    Quests, Flags und Items waren nach dem Laden identisch.
  - Autosave-Probe: Nur der Timer wurde auf 299 s vorgestellt, danach wurde ein periodischer Autosave
    geschrieben.
  - Quit to Title → Continue lädt den neuesten Save, der Prolog ist abgeschlossen.
- **`ui_playtest.gd`: RESULT OK, 217 Checks, 0 fehlgeschlagen.**
  - Auflösungen: 720p, 1080p, 1440p, 4K.
  - Skalierungsdurchläufe bei 720p, **1080p und 4K**, jeweils mit allen UI-Stufen. Bei **100 % und 150 %**
  kommen Restaurierungsfenster, Dialog mit Hinweis, Pausemenü (Save- und Load-Seite), Wegsteine,
  Klassenwahl und Titelbildschirm dazu.
  - Alles bleibt im Bild, nichts wird gequetscht. Screenshots liegen in `tests/output/ui/`.
- Echter Spielstand des Nutzers (v2) als Kopie in `test_saves` geladen: v2→v5 migriert, ohne Warnungen.
  Das Original wurde nicht verändert.

## Spielzeit (Messung, ehrlich eingeordnet)
- Der Skript-Bot braucht für den kompletten Prolog inklusive optionaler Inhalte **≈ 139 s Spielzeit**
  (Charakteruhr, aktive Zeit). Das ist eine **Untergrenze**: Der Bot läuft ohne Umwege, liest Dialoge
  sofort weiter und kennt alle Ziele.
- Spielzeit mit einem menschlichen Spieler wurde **nicht gemessen** (kein menschlicher Playtest).
- Inhaltsumfang:
  - 3 Maps
  - 8 Begegnungen (davon 2 optional)
  - 3 Echos
  - ≈ 20 Gesprächsseiten
  - 2 Restaurierungen
- Der Prolog wurde nicht künstlich verlängert: kein Grind, die Pflicht-Restaurierung nutzt die
  Wagenvorräte.

## Umsetzung je Phase (Kurzfassung)
- **A – Save Foundation 1.1:**
  - Slots und Rotation, Merge-Queue.
  - Periodischer Autosave nach aktiver Zeit; pausiert zählt er nicht.
  - Meilensteine werden nie unterdrückt; ein Fehler löst eine Wiederholung aus.
  - Atomar: Temp-Datei → verifizieren → `.bak` → rename. Beschädigte Dateien und `.bak` werden erkannt.
  - Metadaten, Optionen (Texte wie gefordert), HUD-Anzeige, Titel- und Pausemenü.
  - Respawn ist getrennt vom Speichern.
  - v4-Stände bleiben ladbar.
- **B – Prolog-Fundament:**
  - Datengetriebene Quests mit Schritten und Event-Zielen im bestehenden `QuestLog`; stabile
    `prologue.*`-Flags.
  - Mid-Prolog-Save und -Load ist für jeden Schritt getestet.
  - Trials werden nie gespeichert, abgeschlossene schon. Laden, Abbruch oder Tod setzen zurück.
- **C – Old Road & Broken Cart:** alle geforderten Stationen, englische Tutorialhinweise, Mara-Texte
  wörtlich, Varianten Rootbound Husk, Hollowfang Wolf und Hardened Husk, Notiztext wörtlich. Kisten werden
  nicht dupliziert. Die Eskorte bleibt nicht hängen und erholt sich einmal, ohne Teleport-Spam. Die Straße
  bleibt nach dem Prolog offen.
- **D – Haven:**
  - Sechs Ruinen, keine freien Plots. Restaurierung ist atomar und löst einen Meilenstein-Save aus.
  - Forge, Lager, Training, Klassenstation, Presets und Respec bleiben erreichbar.
  - Dialoge wörtlich. „Restoration unavailable for now.“ für die übrigen vier Ruinen.
  - Haven-Wegstein von Anfang an aktiv, keine Gegner.
- **E – Whispering Stone:**
  - Echos ohne Cheat-Tasten spielbar, Wahltexte und Intro wörtlich.
  - Wegsteine: genau vier geplant, zwei aktiv. Erweckungszeile wörtlich, keine Reise im Kampf.
  - Rückkehrdialoge wörtlich. Edrin deutet die Bedrohung an.
  - Stub „The Roots Remember: The First Signs“.
  - Guardian und Soulbinder sind ausgeblendet.

## Entscheidungen / Abweichungen (zur Prüfung)
- **Haven = bestehende Map `home_base`:** neu aufgebaut und größer. Die Map-ID bleibt, damit alte Saves
  und Übergänge funktionieren; der Anzeigename ist „Haven“.
- **Prologue Grounds** (alte Testsequenz) sind nur noch über ein Entwickler-Tor in der Proving Arena
  erreichbar. Die Proving Arena selbst ist weiter über Havens Westtor zugänglich.
- **Rastplätze heilen** den Spieler. Sie sind Graybox-Ersatz, weil Tränke keine Benutzen-Aktion haben;
  der Fensterlauf zeigte, dass der Wagenkampf sonst knapp wird.
- **Gegnervarianten** sind neue `EnemyConfig`-Daten mit Lebens- und Poise-Overrides und `id`. Die
  Kampfwerte von Spieler und Grunt sind unverändert.
- **Echo-Ziele** wurden neu gesetzt, wie gefordert. Die Mana-Komponente des Arcanist ist als „vier Zauber
  wirken“ umgesetzt, weil Mana voll startet und ein „Mana ≥ X“-Ziel trivial wäre.
- **Wegstein des Whispering Stone** erwacht erst nach der Klassenwahl.
- Das **Nordtor von Haven** öffnet nach Edrins Gespräch.
- Der Wahl-Altar heißt im Spiel „Heart of the Stone“, damit er nicht mit dem Wegstein „The Whispering
  Stone“ verwechselt wird.
- Ein v4-Charakter, der den Prolog abgeschlossen hat, bekommt den Whispering-Stone-Wegstein aktiv. Sonst
  könnte er nie dorthin schnellreisen, weil sein Prolog keine Wegstein-Erweckung mehr enthält.
- Debug-Overlay und F-Tasten-Leiste sind weiter sichtbar, wie bisher. Sie wurden im Fensterlauf nicht
  benutzt.

## Nicht getan / offen
- **Menschlicher Playtest steht aus.** Über Spielgefühl, Schwierigkeit der Varianten, Lesbarkeit der
  Hinweise und Eskortengefühl wird hier nichts behauptet.
- Nicht im Umfang:
  - volles Hollowwood
  - Guardian und Soulbinder
  - neue Waffenfamilien
  - freies Bauen
  - craftbare Wegsteine
  - komplexe Begleiter-KI
  - finale Grafik und Audio
  - Balance-Änderungen
- Revitalisierung der Ruinen ist nur in den Daten vorbereitet.
- Gegnernamen werden nicht über den Gegnern angezeigt.
- Slots lassen sich im Menü nicht umbenennen oder löschen.
- Die Spielzeit menschlicher Spieler muss im Playtest gemessen werden.
