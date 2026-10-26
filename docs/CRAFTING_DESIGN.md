# Crafting – Resonanzschmieden (Crafting Foundation 0.1)

Status-Legende: ✅ implementiert · 🟡 teilweise · 🔧 nur vorbereitet · ⬜ offen
Alle Zahlen sind **Testwerte** für den Vertical Slice, keine Balance-Vorgaben.

## Verbindliche Designregeln → Umsetzung
| # | Regel | Umsetzung |
|---|---|---|
| 1 | Loot und Gecraftetes gleichwertig, verschiedene Vorteile | Crafting = gezielte Steuerung (Material, Fokus, sichtbare Chancen); handgestaltete Uniques/Legendaries behalten ihre Kerne. 🟡 Loot-Generator existiert noch nicht |
| 2 | Genau ein Hauptmaterial | `ItemInstance.material_id`, gesetzt beim Prägen, danach permanent ✅ |
| 3 | Zusatzmaterialien als Zutaten/Katalysatoren | Material-Kosten beim Prägen, Fokuskatalysator, Essenzen, Sockeleinlagen ✅ |
| 4 | Material → Prägung, Affixgewichte, Essenzsynergien | `MaterialDefinition`: Prägungs-Stats, Tag-Gewichte, Essenz-Affinität (×1,25) ✅ |
| 5 | Affixe mit Tags, Tiers, Bereichen, Gewichten, Ausschlussgruppen | `AffixDefinition` + `AffixTier` ✅ |
| 6 | Mögliche Ergebnisse + echte Wahrscheinlichkeiten sichtbar | `CraftingPreview.outcomes` = exakt der gewürfelte Pool ✅ |
| 7 | Umformen ersetzt sofort | Reforge ersetzt den Affix beim Bestätigen, kein Behalten/Verwerfen ✅ |
| 8 | Schlechter möglich, nie Itemzerstörung | Kein Operationspfad entfernt Items; Kosten nie Ausrüstung (validiert) ✅ |
| 9 | Bis zu zwei kombinierbare Essenzen | `essence_slots` ≤ 2 (Profil, Service, Laden) ✅ |
| 10 | Extraktion mit seltener Ressource, Ersetzen verbraucht | Essence Siphon; Ersetzen verbraucht die alte Essenz (Hinweis vorab) ✅ |
| 11 | Uniques begrenzt veränderbar, explizit definiert | `CraftingProfile.allowed_operations` (Crushing Oath: Qualität + Sockel) ✅ |
| 12 | Sockel unabhängig von Essenzplätzen | eigene Liste `sockets`, eigene Grenzen ✅ |
| 13 | Crafting- vs. Upgrade-Währungen | `CraftingCurrencyDefinition.Kind` CRAFTING/UPGRADE/CATALYST/EXTRACTION ✅ |
| 14 | Nur gekennzeichnete Items entwickeln sich | `CraftingProfile.evolution_id` ✅ |
| 15 | Wählbare Mutationspfade | Stufe 3 mit zwei Mutationen, Wahl permanent ✅ |
| 16 | Waffenbeherrschung ≠ Item-Evolution | Item-EP auf der Instanz, eigene Quelle; Mastery unverändert ✅ |

## Hauptmaterialien (`data/crafting/materials/`)
| Material | Item (Kosten Prägung) | Garantierter Effekt | Tag-Gewichte | Essenz-Affinität |
|---|---|---|---|---|
| Bloodsteel | Bloodsteel Ingot ×3 | +5 Physical Damage %, +1 Life on Hit | blood ×3, physical ×2, crit ×1,5 | – |
| Storm Ore | Storm Ore ×3 | +10 Shock Damage %, +3 Attack Speed % | shock ×3, speed ×2, crit ×1,5 | Storm Wolf |
| Frost Glass | Frost Glass ×3 | +8 Poise Damage %, +10 Knockback % | control ×3, poise ×2, defense ×1,5 | Stone Golem |

„Blutung“ und „Kälte“ sind bewusst **keine** neuen Statussysteme (Auftrag): Blut nutzt Life on Hit,
Frost nutzt Kontrolle über Haltung und Knockback (Combat-Polish-Modell).

## Affixe (`data/crafting/affixes/`, 12)
Tiers: T3 ab Itemlevel 1 (Gewicht 100), T2 ab 10 (60), T1 ab 20 (25). Affix-Grundgewicht 100.
| Affix | Stat | Tags | Gruppe / Ausschluss | Slots | T3 / T2 / T1 |
|---|---|---|---|---|---|
| Sharpened | Physical Damage % | physical, attack | – | Waffen | 4-7 / 8-12 / 13-18 |
| Swift | Attack Speed % (vorbereitet¹) | speed | – | Waffen | 3-5 / 6-8 / 9-12 |
| Keen | Crit Chance % | crit | – | Waffen, Ring, Hals | 2-3 / 4-5 / 6-8 |
| Cruel | Crit Damage % | crit, physical | – | Waffen | 10-15 / 16-25 / 26-35 |
| Crushing | Poise Damage % | poise, control | control_core | Waffen | 6-10 / 11-16 / 17-24 |
| Vital | Max Health | defense, life | – | alle | 8-14 / 15-24 / 25-36 |
| Guarded | Armor | defense | – | Rüstung, Schild | 5-8 / 9-14 / 15-22 |
| Furious | Resource Gain % | resource | – | alle | 8-12 / 13-20 / 21-30 |
| Executioner's | Heavy Finisher Power % | finisher, heavy | – | Waffen | 8-12 / 13-20 / 21-30 |
| Thundering | Shock Damage % | shock, elemental | element_core | Waffen | 10-15 / 16-25 / 26-40 |
| Bloodthirsty | Life on Hit | blood, life, physical | element_core | Waffen | 1 / 2 / 3-4 |
| Impactful | Knockback % | control | control_core | Waffen | 10-15 / 16-25 / 26-35 |

¹ Attack Speed wird berechnet und angezeigt, verändert aber **keine** Combat-Timings (verbindlich).

Neue Stats, alle an vorhandene Mechanik gekoppelt (`CharacterStatModifier`, Bridge):
Crit Damage (Krit-Multiplikator), Heavy Finisher Power (Schaden + Haltung bei `heavy`+`finisher`),
Knockback % (einmal auf die Knockback-Distanz, der Empfänger skaliert seine Resistenz einmal),
Resource Gain (Wut-Aufbau), Life on Hit (Heilung je Treffer), Shock Damage (Entladung).

## Affix-Pool (`AffixPool`)
Gewicht je Eintrag = Affixgewicht × Tier-Anteil (Tiergewicht / Summe der zulässigen Tiers) ×
Material-Multiplikator (größter passender Tag) × Fokus-Multiplikator (×4, falls Fokus-Tag).
Ausgeschlossen: falscher Itemtyp, Itemlevel zu niedrig, gleiche Gruppe vorhanden, gleiche
Ausschlussgruppe vorhanden, keine freien Affixplätze (beim Ersetzen zählt der ersetzte Affix nicht).
Die Wahrscheinlichkeiten werden normalisiert. Ziehung: ein `rng.randf()` über die kumulierte Liste
(injizierbarer `RandomNumberGenerator`), danach ein `randi_range` für den Wert.

## Operationen (`data/crafting/operations/`) und Währungen
| Operation | Kosten | Wirkung |
|---|---|---|
| Imprint (Prägen) | 1 Imprint Shard + 3 Material | Hauptmaterial setzen + erster Affix |
| Augment (Erweitern) | 2 Imprint Shards | +1 Affix (max. 4 Plätze) |
| Reforge (Umformen) | 1 Transmutation Core | gewählten Affix sofort neu würfeln |
| Fokus (optional) | +1 Focus Catalyst | Tag ×4 bei Imprint/Augment/Reforge |
| Bind Essence | die Essenz selbst | in freien Platz; Ersetzen verbraucht die alte |
| Extract Essence | 1 Essence Siphon | Essenz zurück ins Inventar |
| Open Socket | 1 Socket Chisel | +1 offener Sockel (Limit je Item) |
| Insert / Remove Gem/Rune | Einlage selbst / kostenlos | Entnehmen gibt die Einlage zurück |
| Upgrade Quality | 1 Forge Crystal | Qualität +1 (max. 20), Basiswerte +1 % je Punkt |
| Evolve | Stufenkosten (+ Awakening Stone für Stufe 3) | nächste Evolutionsstufe |

Transaktion (`CraftingService`): validieren → Pool → Kosten prüfen → einmal würfeln → Kosten
abziehen + Item ändern → `Character.notify_item_changed` (Stats/Effekte bei ausgerüsteten Items).
Abgelehnte Vorgänge verbrauchen nichts. Jede Anfrage trägt die Item-Revision ihrer Vorschau;
eine zweite Ausführung derselben Vorschau wird abgelehnt (Doppelklick-Schutz).

## Essenzen und Resonanz (`data/crafting/essences/`, `resonances/`)
| Essenz | Wirkung | Grenzen |
|---|---|---|
| Storm Wolf | Heavy-Finisher-Treffer → Entladung (Radius 44): 35 % des Treffers als Schockschaden × Shock Damage × Essenzkraft, 6 Haltung, 4 px Knockback, markiert Getroffene 2 s als „charged“ | 1× pro Schwung für alle Träger, 0,8 s Abklingzeit, Entladung läuft nicht durch Modifier/Effekte (keine Ketten), keine XP |
| Stone Golem | Voll aufgeladene Heavy-Finisher: +60 % Haltungsschaden × Essenzkraft | 1× pro Treffer auch bei zwei Trägern |
| **Thunderquake** (beide in derselben Waffe) | Der nächste Spielertreffer gegen ein „charged“-Ziel: +50 % Haltungsschaden | eine Markierung = ein Bonus, läuft nach 2 s ab |

Essenzkraft = 1,25, wenn das Hauptmaterial Affinität hat (Storm Ore ↔ Storm Wolf, Frost Glass ↔ Stone Golem).
Beobachtung im Playtest: Ein voll aufgeladener L-L-H stößt einen Grunt auf ~52 px weg. Für die
Resonanz muss man nachsetzen, denn die Markierung hält nur 2 s.

## Sockel und Qualität
- Garnet (Edelstein): +20 Max Health. Rune of Impact (Rune, nur Waffen): Heavy-Treffer +25 %
  Knockback, +15 % Haltung (`TaggedHitModifierEffect`).
- Sockelgrenzen: Forged Blade/Greatsword 2, Crushing Oath 1. Sockel werden einzeln geöffnet.
- Qualität 0–20: +1 % auf die Basiswerte (oder `quality_stats`), nie auf Affixe/Effekte.
  Itemlevel ist unabhängig.

## Evolution (`data/crafting/evolutions/stormcaller.tres`)
Stormcaller Fang (Epic, einhändig, `evolving`):
| Stufe | Voraussetzung | Bonus |
|---|---|---|
| 1 Dormant | – | – |
| 2 Awakened Edge | 60 Item-EP, 5 Iron Ore, 2 Hollow Essence | +6 Physical Damage %, +10 Heavy Finisher Power % |
| 3 Ascended | 150 Item-EP, 1 Awakening Stone, 3 Hollow Essence, **Mutationswahl** | Pfad A Storm Charge: Heavy-Finisher +30 % Schaden/Knockback · Pfad B Steadfast: +40 Rüstung, voll aufgeladene Heavies +40 % Haltung |

Item-EP: 1 je akzeptiertem Treffer gegen echte Gegner (nicht Trainingspuppen), +4 bei
Heavy-Finishern, nur für das Main-Hand-Item des aktiven Loadouts. Die Wahl ist permanent
(kein Respec in 0.1).

## UI (Resonance Forge, Schmiede)
Interaktion (G) mit der gebauten Schmiede öffnet die Forge (`CraftingPanel`, `UiWindow`):
- **Linke Spalte:** Items mit Tooltip und Bestand.
- **Mitte:** Details. Der handgestaltete Kern erscheint als „Core (protected)“ und ist nicht
  auswählbar.
- **Rechte Spalte:** Aktionen, Parameter, Kosten mit Bestand, Hinweise, exakte Chancen je Affix
  und Tier, Bestätigen, Ergebnis.

Die Forge ist responsiv: Bei hoher UI-Skalierung werden die Spalten gestapelt und das Fenster
scrollt. „Smithy recipes“ führt zum alten Rezept zurück. F4 gibt ein Debug-Crafting-Kit.

## Offen
⬜ Loot-Generator mit Affixen · ⬜ Essenz-Drops von Monstern (nur Debug-Kit) · ⬜ Respec ·
⬜ echte Element-/Statussysteme · ⬜ Attack Speed wirksam machen (nur nach Combat-Playtest) ·
⬜ VFX/SFX für Resonanz · ⬜ weitere Basen/Materialien.
