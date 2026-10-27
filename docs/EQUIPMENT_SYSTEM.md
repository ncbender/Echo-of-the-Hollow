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

## Waffenregeln ✅
| Fall | Regel |
|---|---|
| Zweihandwaffe | nur Hauptwaffe; Nebenhand wird logisch blockiert und **geleert** |
| Waffen allgemein | **genau ein Waffen-Slot** (Hauptwaffe, Weapon Mastery 1.4): keine Waffe in der Nebenhand, kein Dual Wield (`can_dual_wield` ungenutzt) |
| Einhand + Schild | Schild nur Nebenhand, nur wenn Klasse `can_use_shields` |
| Nebenhand bei ausgerüstetem Zweihänder | Zweihänder wird abgelegt |
| Klassen-/Familienregeln | `required_class_ids`; jede Klasse darf jede Waffenfamilie führen (`allowed_weapon_families` leer) |

**Sichere Transferregel:** Alles, was durch ein Ausrüsten verdrängt wird, verliert nur die Referenz und
bleibt im Inventar; die UI meldet „Moved back to inventory: …“ (`CharacterEquipment.last_displaced`).

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
