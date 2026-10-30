# Equipment-System

Status-Legende: ✅ implementiert · 🟡 teilweise · 🔧 nur vorbereitet · ⬜ offen

## Slots ✅ (15, `EquipSlot.Slot`)
Kopf, Schultern, Rücken, Brust, Handgelenke, Hände, Gürtel, Hose, Schuhe, Hauptwaffe, Nebenhand,
Ring 1, Ring 2, Halskette, Trinket. Zuordnung über `ItemDefinition.slot_kind`.

## Shared-Item-Policy (Entscheidung) ✅
**Variante 1:** Items liegen physisch nur im Inventar. Jedes Klassen-`Loadout` speichert Instanz-IDs.
Dieselbe Instanz darf in den Loadouts **mehrerer Klassen** referenziert sein; wirksam ist nur das
Loadout der **aktiven** Klasse. Innerhalb eines Loadouts höchstens einmal.
*Begründung:* Kein Transfer beim Klassenwechsel nötig, Duplikation und Verlust sind strukturell
ausgeschlossen (es gibt genau einen Speicherort), Verwerfen entfernt automatisch alle Referenzen.

## Equipment Inventory Separation 1.0 ✅ (Ort eines Items)
Ein Item hat genau einen Ort: **Tasche**, **Ausrüstungs-Slot** oder **Haven-Lager** (`Character.stash`).
Besitzer bleibt das Inventar (Save v15 unverändert: Items in `inventory`, Loadouts referenzieren IDs), der Ort
ergibt sich daraus:
- Steckt die Instanz im Loadout der **aktiven Klasse** (während eines Trials: im Loadout der echten Klasse), liegt
  sie im Ausrüstungs-Slot: `Inventory.in_equipment` / `takes_slot` = kein Taschenplatz, nicht im Taschenraster
  (Inventar- und Lagerfenster), nur in der Paper Doll. Zählung über `Inventory.equipped_check` →
  `CharacterEquipment.in_equipment` (Methoden-Callable, kein Zyklus).
- Items **inaktiver** Klassen-Loadouts sind Taschen-Items (belegen einen Platz).
- **Anlegen:** das neue Item macht seinen Platz frei, Verdrängtes braucht einen (direkter Tausch nutzt den
  freigewordenen Platz). **Ablegen:** braucht einen freien Platz. **Presets** (`apply_loadout`) und
  **Klassenwechsel** (`Character.switch_class` → `class_switch_error`) genauso. Passt es nicht, wird abgelehnt
  (`CharacterEquipment.BAG_FULL` bzw. „too full to change class“) und **nichts** ändert sich - atomar,
  ohne Verlust oder Duplikat. Eine Änderung, die die Tasche nicht voller macht, ist immer erlaubt.
  `loadout_error` liefert das Urteil von `apply_loadout` ohne Änderung (gemeinsames `_plan_loadout`, Tasche im
  Zielzustand gemessen); `PresetService.validate` nutzt es, damit eine Preset-Aktivierung alles oder nichts ist
  (`TALENT_SYSTEM.md`, Preset Activation Atomicity Fix 1.0). `restore_loadout` stellt einen gesicherten Zustand
  exakt wieder her (Rollback).
- **Laden:** `Inventory.from_array` prüft keinen Platz mehr (welche Items in Slots liegen und die Endkapazität
  sind erst nach Loadouts und Gebäuden bekannt) - kein gespeichertes Item wird wegen Platzmangel verworfen.
  Alte v15-Saves laden unverändert (deterministisch, idempotent); die Tasche hat danach nur mehr Platz.
- Bewusst offen: Prolog-Klassenwahl (`PrologueService.choose_starting_class`) und das Ende eines Trials werden
  nicht abgelehnt; sie können eine Tasche theoretisch überfüllen (kein Verlust, nur kein neues Item, bis Platz ist).

## Waffenregeln ✅
| Fall | Regel |
|---|---|
| Zweihandwaffe | nur Hauptwaffe; Nebenhand wird logisch blockiert und **geleert** |
| Waffen allgemein | **genau ein Waffen-Slot** (Hauptwaffe, Weapon Mastery 1.4): keine Waffe in der Nebenhand, kein Dual Wield (`can_dual_wield` ungenutzt) |
| Einhand + Schild | Schild nur Nebenhand, nur wenn Klasse `can_use_shields` |
| Nebenhand bei ausgerüstetem Zweihänder | Zweihänder wird abgelegt |
| Klassen-/Familienregeln | `required_class_ids`; jede Klasse darf jede Waffenfamilie führen (`allowed_weapon_families` leer) |

**Sichere Transferregel:** Alles, was durch ein Ausrüsten verdrängt wird, verliert nur die Referenz und
kommt zurück in die Tasche (braucht dort Platz, sonst wird das Ausrüsten abgelehnt); die UI meldet „Moved back
to the bag: …“ (`CharacterEquipment.last_displaced`).

Die **Combat-Waffenfamilie folgt der Hauptwaffe** (Wechsel erst, wenn die Aktionsschicht frei ist).
Ohne Hauptwaffe: `fallback_weapon_family` (Platzhalter bis waffenloser Kampf existiert).
Es gibt **keinen Waffen-Schnellwechsel**: die Waffe wird im Inventar gewechselt (Tasten 1/2 sind Hearth Flask und
Spezialtrank). Ein Wechsel beendet die laufende Combo und ihren Puffer.
Ältere Spielstände oder Presets mit einer Waffe in der Nebenhand: die Referenz wird beim Laden bzw. Anwenden
verworfen, die Waffe bleibt in der Tasche.

## Stat-Resolver ✅ (`StatResolver`, `Character.get_stats()`)
`final = Σflat · (1 + Σpercent/100)` über Charakter-Basis + Klasse(Level) + aktive Ausrüstung
(Basiswerte + Affixe) + erreichte Set-Boni. **Immer komplett neu berechnet** (nie inkrementell) →
keine Restboni, keine Doppelanwendung (getestet mit 20× An-/Ablegen).

| Stat | Wirkung |
|---|---|
| Max Health ✅ | Spieler-Lebenspunkte (Verhältnis bleibt beim Ändern) |
| Physical Damage ✅ | +% auf ausgehenden Trefferschaden (über `AttackModifier`) |
| Armor ✅ | eingehender Schaden × 100/(100+Armor) |
| Crit Chance ✅ | % Chance auf ×1,5 Schaden (`crit`-Tag) |
| Attack Speed 🔧 | berechnet/angezeigt, **bewusst nicht** auf Combat-Timings angewendet (Feel-Test) |
| Poise Damage ✅ | +% Haltungsschaden |

Ohne Ausrüstungsboni sind alle offensiven Werte neutral → Combat-Balance unverändert.

## Offen
⬜ Waffen-Basisschaden pro Item (aktuell nur Prozentboni), ⬜ Offhand-Angriffe, ⬜ Ausrüstungsvergleich in der UI.
