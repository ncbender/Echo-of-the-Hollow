# Klassensystem

Status-Legende: ✅ implementiert · 🟡 teilweise · 🔧 nur vorbereitet · ⬜ offen

## Modell ✅
- `ClassDefinition` (`data/classes/*.tres`): ID, Name, Level-Kurve, Grundwerte + Werte pro Level,
  Waffen-/Schild-/Dual-Wield-Regeln, Freischalt-Hinweis, Ressource, Skill-Slots 🔧, Talentbaum-ID 🔧.
- `CharacterClasses` (Laufzeit, gespeichert): pro Klasse `unlocked`, `level`, `xp`; aktive Klasse.
- Registrierung: jede `.tres` in `data/classes/` wird von `GameDatabase` geladen – beliebig viele Klassen.

| Klasse | Status | Besonderheiten |
|---|---|---|
| Basic Adventurer | Start, freigeschaltet | neutrale Werte, +2 HP/Level, **keine Schilde**, max. Lv 10 |
| Warrior | gesperrt (`prologue.choice`) | +20 HP, +10 Rüstung, +5 % Haltungsschaden, +4 HP/+1 Rüstung pro Level, Schilde, **Wut** |

## Regeln ✅
- Gesperrte Klassen können nicht aktiviert werden.
- Wechsel nur an einer **Klassenstation** (`ClassStation`, Interaktion **G**); `Character.switch_class()`
  lehnt Wechsel außerhalb ab.
- Beim Wechsel: aktive Klasse + Level wirksam, Stats neu berechnet, **eigenes Loadout aktiv**,
  Waffenbeherrschung und Inventar bleiben (geteilt), Effekte/Waffe werden neu aufgebaut.
- Beim ersten Freischalten erhält eine Klasse eine Kopie der *Referenzen* des aktuellen Loadouts
  (nur erlaubte Items) – bequemer Start, keine Item-Kopie.
- Klassen-XP geht an die aktive Klasse (Treffer, Kills, Debug **F8**).

## Klassenressourcen ✅/🔧
Generisch: `ClassResourceDefinition` (Max, Start, Regeneration/Zerfall, Verzögerung, Gewinn bei
Treffer/Getroffenwerden) + Laufzeit-`ClassResourcePool` (nicht gespeichert). Beispiel **Wut** (Krieger):
+8 pro Treffer, +5 pro erlittenem Treffer, zerfällt nach 3 s mit 10/s. Anzeige im Klassenfenster.
`spend()` existiert für spätere Skills; noch kein Verbraucher. Mana/Fokus/… = nur neue Daten.

## Integrationsschnittstelle für den Prolog 🔧
Der spätere Prolog ruft nur auf:
```gdscript
character.classes.unlock(&"warrior")            # Klasse freischalten (Quest/Boss/Prolog)
character.switch_class(&"warrior", in_safe_zone) # Wechsel an sicherem Ort
```
`ClassDefinition.unlock_condition` dokumentiert die Quelle (`prologue.choice`, `quest.<id>`, `boss.<id>`).
Die Prolog-Klassenprüfung selbst ist **nicht** implementiert.

## Offen
⬜ Skills (Q/E/R/F), ⬜ Talentbäume, ⬜ weitere 13+ Klassen, ⬜ Klassen-Level-Anforderungen an Items
(`required_class_level` vorbereitet, nicht geprüft).
