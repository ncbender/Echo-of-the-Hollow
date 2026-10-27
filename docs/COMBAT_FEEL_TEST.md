# Combat Feel Test – manueller Spielgefühl-Test

Isolierte Testumgebung für One-Handed Sword, Daggers, Greatsword und Bow. Sie nutzt die vorhandene Arena
(`scenes/arena/test_arena.tscn`) mit dem echten Player, `CombatComponent` (Combat Flow 1.5), Input, Weapon Mastery und
Burden. Es gibt keine eigene Combat-Implementierung, keine neuen Werte und keine neuen Mechaniken.

## Start

Im Projektordner (Fenster, nicht headless):

```
..\tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . -s res://tests/playtest/combat_feel_test.gd
```

- Der Start erfolgt direkt in der Arena, ohne Prolog, Haven-Reise, Trials oder Questfortschritt.
- Automatische Selbstprüfung (Start, Waffenwechsel, Mastery-Umschalter, echte Treffer, zwei Screenshots in `tests/output/combat_feel/`, danach Ende):

  ```
  ... -s res://tests/playtest/combat_feel_test.gd -- --selftest
  ```

> Die Arena **nicht** direkt per Editor-„Szene starten“ (F6) testen: Dann ist die Session nicht isoliert und nutzt den
> echten Save-Pfad, die echten Einstellungen und das periodische Autosave.

## Isolierung (keine echten Spielstände)

- Das Skript läuft als Hauptschleife, die Session gilt deshalb als „scripted“.
  - Einstellungen liegen nur im Speicher; `settings.cfg` wird nicht gelesen und nicht geschrieben.
  - Speicherpfad: `user://test_saves/combat_feel/slot_1.save.json`.
- Das periodische Autosave ist aus. Der Charakter ist bei jedem Start ein frischer Testcharakter.
- F6 (Speichern) und F9 (Laden) schreiben bzw. lesen nur den Testpfad; Debug-Items landen nie in regulären Saves.

## Steuerung

| Taste | Wirkung |
|---|---|
| **T** | nächste Waffe: One-Handed Sword → Dagger → Greatsword → Bow (normal über Inventar und Ausrüstung; Wechsel erst, wenn der Angriff vorbei ist) |
| **Y** | Mastery der vier Familien: Level 1 (nur Grundangriffe) ↔ Level 20 (alle Pfade, Bogen inkl. Flowing Draw) |
| LMB | Quick (L); Bogen: Quick Shot; LMB halten ab Mastery 10: Flowing Draw |
| RMB | Heavy (H) sofort; Bogen: halten = Precision Stance (65 % Gehen), LMB dabei = Precision Shot (P) |
| Space / Shift | Dash / Block und Parry (Werte unverändert) |
| F1 | Hitboxen und Bewegungsvektoren anzeigen |
| F2 | echten Grunt spawnen (Gegner, der zurückschlägt) |
| F5 | Arena zurücksetzen (Waffe und Mastery bleiben) |
| F12 | Debug-Overlay: Phase, Angriff, Kette, Puffer, Flowing Draw |

**Ziele:**
- links ein einzelner Trainingsdummy, rechts eine Gruppe aus drei Dummies.
- Die Dummies haben sehr viel Leben und reagieren mit den vorhandenen Treffer- und Haltungsrückmeldungen.

Oben links steht eine Info-Zeile mit Waffe, Mastery, Burden-Stufe und laufender Kette. Burden ergibt sich aus der
getragenen Startausrüstung (Light); Rüstung lässt sich im Inventar (I) wechseln.

## Pfade zum Ausprobieren (Mastery 20)

- Nahkampf: L-L-L, L-L-H, L-H-L, H-L-L, L-H-H, H-L-H, H-H-L, H-H-H; den nächsten Input im Annahmefenster der laufenden Recovery drücken.
- Bogen: L-L, L-P, P-L, L-L-P, P-L-P, L-P-L, P-L-L-P und Flowing Draw.
- Namen und Freischaltlevel stehen an der Klassenstation (C), Seite „Weapons“.

## Platzhalter und Einschränkungen

- **Animationen:** Alle Angriffe nutzen generische Platzhalter.
  - Nahkampf: Schwung-Wedge und Klingenstrich, je Schritt abwechselnd links/rechts.
  - Bogen: Bogenbogen mit Sehne beim Windup, Blitz beim Fire-Event, Pfeil als Messer-Form.
  - Es gibt keine finalen Animationen; Endknoten haben keine eigene Optik.
- **Werte:** Schaden, Haltung, Geometrie und Angriffsbewegungen sind die dokumentierten Prototyp- bzw. Platzhalterwerte (`docs/WEAPON_MASTERY_COMBAT_FLOW.md` §8). Hier ist nichts geändert.
- **Nicht in diesem Test:** Heavy Impact, Charged-Heavy-Talente, neue Finisher und Hitstop-Änderungen sind bewusst nicht enthalten.
- **Klasse:** Die Testfigur ist Basic Adventurer Level 1. Klassenskills (Q/E/R/F) sind nur vorhanden, soweit diese Klasse sie hat.
- **Arena-Reste:** Die übrigen Arena-Inhalte (Klassenstation, Pickups, Map-Name „Prologue Grounds (dev)“, Journal-Anzeige) stammen aus der vorhandenen Szene. Questfortschritt entsteht hier nicht.
