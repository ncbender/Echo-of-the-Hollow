# Armor Mastery Foundation 1.0

Regeln nur in `ArmorMasteryService`, Zustand in `Character.armor_mastery` (`CharacterArmorMastery`, Save v10), Werte in
`ArmorMasteryRules` (`ProgressionRules.armor_rules()`).

## Rüstungsarten
- `ItemDefinition.armor_type`: Cloth, Leather, Mail, Plate (NONE = keine Rüstung oder nicht eindeutig).
- Alle Klassen tragen alles und mischen frei.
- Zugeordnet wurden nur eindeutige Daten:
  - Leather: Leather Cap, Leather Gloves, Worn Boots
  - Cloth: Linen Trousers
  - Mail: Warden Helm/Mail/Greaves (Set „Hollow Warden“, „mail“ im Namen)
- Ohne Typ (offen): Wanderer's Coat, Warlord Helm. Plate gibt es in den Daten noch nicht; Tests nutzen Testitems.

## Burden
- Gezählt werden nur die fünf vorhandenen Slots Head, Chest, Hands, Legs, Feet. Shoulders, Back, Wrists, Belt,
  Waffen und Schilde zählen nicht.

| Slot | Cloth | Leather | Mail | Plate |
|---|---|---|---|---|
| Head | 1 | 2 | 3 | 5 |
| Chest | 3 | 5 | 8 | 13 |
| Hands | 1 | 2 | 3 | 5 |
| Legs | 2 | 4 | 6 | 10 |
| Feet | 1 | 2 | 4 | 6 |

- Stufen: 0–14 Light (keine Strafe), 15–25 Balanced (−2 % Gehtempo, +2 % Attack-Recovery-Dauer), 26–37 Burdened
  (−5 % / +5 %), 38+ Heavy (−8 % / +8 %). Volle Platte = 39 = Heavy.
- Gehtempo über `Player.move_speed_multiplier` (nur Laufen). Recovery über `CombatComponent.recovery_multiplier`
  (nur die Recovery-Phase).
- Dash (Distanz, iFrames, Ladungen, Aufladung) und Parry-/Block-Fenster bleiben unberührt.

## Mastery-XP (Werte provisorisch)
- Vier charakterweite Tracks, Stufe 1–20, bleiben bei Klassenwechsel.
- XP bis zur nächsten Stufe: round(100 · 1,15^(n−1)), provisorisch.
- Quellen:
  - Kill: die Kill-Mastery-XP des Gegners (`EnemyConfig.mastery_xp_reward`), einmal pro Gegnerinstanz, auch bei
    Kills durch Skills.
  - Block oder Parry eines echten gegnerischen Angriffs: 3 XP, einmal pro Angriff, höchstens 15 XP je Gegner
    (kein Farmen eines schwachen Gegners).
  - Nicht: eingesteckte Treffer, Trainingsziele.
- Verteilung nach getragener Abdeckung: Head 15 %, Chest 40 %, Hands 10 %, Legs 25 %, Feet 10 %. Anteile leerer oder
  typloser Slots gehen verloren.

## Meilensteine (skalieren mit der Abdeckung des Typs)
| Typ | 5 | 10 | 15 | 20 |
|---|---|---|---|---|
| Cloth | +2 % Magic Resistance | +2 % Skill Recovery Speed | +2 % Magic Resistance | +2 % Skill Recovery Speed |
| Leather | +1 % Movement | +2 % Attack Recovery Speed | +1 % Movement | +2 % Attack Recovery Speed |
| Mail | +3 % Poise | +2 % Block Efficiency | +3 % Poise | +2 % Block Efficiency |
| Plate | +2 % Poise | +1 % Physical Damage Reduction | +2 % Poise | Iron Discipline: bis 1 Punkt weniger Burden-Gehstrafe |

Wirkung:
- **Magic Resistance:** nicht-physischer erlittener Schaden. Gegner machen bisher nur physischen Schaden → derzeit
  ohne sichtbare Wirkung.
- **Skill Recovery Speed:** Cast-Lock eines Skills ÷ (1 + x).
- **Attack Recovery Speed:** Recovery-Phase ÷ (1 + x).
- **Poise:** max. Poise des Spielers. Spieler-Poise hat bisher keine Spielwirkung (kein Poise-Bruch beim Spieler)
  → derzeit ohne sichtbare Wirkung.
- **Block Efficiency:** zusätzlicher Anteil weniger Schaden beim Blocken.
- **Physical Damage Reduction:** physischer erlittener Schaden.

## UI
Skills & Talents (C / Klassenstation), Seite „Armor“ (Skills & Talents UX 2.0 Phase 7, `SKILLS_TALENTS_UX_2_0.md`):
- oben Burden: Punkte und Stufe, Strafen, Iron Discipline, Stufenbereiche aus den Regeln, die fünf Slots
- 2 × 2 Mastery-Karten: Stufe, XP-Balken, „WORN n%“, wirksame Boni (je Stat summiert), nächster Meilenstein
- Details des gewählten Tracks: Fortschritt, getragene Slots, alle Meilensteine (jetzt wirksam / erreicht, aber
  nicht getragen / nächster / offen)
- Auswahl ändert nichts; nur Anzeige über `ArmorMasteryService`

Das Fenster nimmt immer die volle Größe ein; die Book Tabs springen beim Seitenwechsel nicht.
