# Talent Structure Rework 1.0 - Free Specialization Progression

Ziel: weiterhin drei Spezialisierungen je Klasse mit Tiers, aber innerhalb eines Baums echte Wahlfreiheit statt
einer Pflichtschiene. Nur Struktur, Daten und Freischaltung - **kein** visuelles Talent-Redesign (nächste Phase).
Save v15 unverändert, keine Migration.

## 1. Bisherige Struktur

- 3 Klassen × 3 Bäume × 13 Knoten = 117 Talente.
- 7 Tiers je Baum: Tier 1–6 mit je **zwei** Knoten (Spalte 0: 5 oder 3 Ränge; Spalte 1: 3 Ränge oder ein
  Aktiv-/Transformations-Talent mit 1 Rang), Tier 7 = ein Endtalent.
- Freischaltung schon damals über Punkte: Tier t brauchte `5 × (t − 1)` Punkte in den **niedrigeren** Tiers desselben
  Baums (0 / 5 / 10 / 15 / 20 / 25 / 30).
- Explizite Parent-Voraussetzungen gab es nur 6 (Cyclone → Whirlwind, Lance of Stars → Astral Lance,
  Grand Rift → Arcane Rift, Fan of Knives / Piercing Blades → Blade Fan, Choking Smoke → Smoke Veil).
- Die Talentseite zeichnete zusätzlich dünne Linien von jedem Knoten zum Knoten derselben Spalte im nächsten Tier.

## 2. Warum das zu pfadgebunden war

Die Pflichtschiene entstand nicht durch Prerequisites, sondern durch **Schwellen-Mathematik + Linienbild**:

| Tier-Schwelle (alt) | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|
| nötig / Rangkapazität darunter (Berserker) | 5 / 8 | 10 / 12 | 15 / 18 | 20 / 26 | 25 / 30 | 30 / 38 |
| Anteil, der Pflicht war | 63 % | **83 %** | **83 %** | 77 % | **83 %** | 79 % |

- Je Tier nur zwei Knoten → höchstens eine Entweder-oder-Wahl, die wegen der hohen Schwellen meist keine war:
  Für Tier 3 mussten 10 von 12 möglichen Rängen gesetzt sein, d. h. praktisch alles aus Tier 1 und 2.
- Sechs aufeinanderfolgende Schwellen → derselbe Zwang sechsmal hintereinander.
- Die impliziten Spaltenlinien sahen aus wie Parent-Ketten (zwei „Schienen“ von oben nach unten), obwohl die
  Regeln sie nie verlangten.

## 3. Neue Zielregeln

- Jede Klasse behält 3 Bäume; jeder Baum hat **4 Tiers**: Tier 1–3 mit je **vier** frei wählbaren Talenten,
  Tier 4 = das Endtalent.
- Ein Tier öffnet **nur** über Punkte, die im eigenen Baum in niedrigeren Tiers liegen. Welche Talente die Punkte
  tragen, ist egal; innerhalb eines offenen Tiers ist jedes Talent sofort wählbar.
- Parent-Voraussetzungen nur für direkte Upgrades eines Aktiv-Skills (unverändert 6, alle bleiben, weil ein Upgrade
  ohne den Skill wirkungslos wäre). Kein Endtalent und kein Passive hat eine Voraussetzung.
- Bäume bleiben frei mischbar; Punkte anderer Bäume zählen nie.
- Die Regel ist für alle Klassen dieselbe (`TalentRules.tier_points`, `TalentRules.TIERS = 4`, `TalentRules.COLUMNS = 4`)
  und steht weiterhin an genau einer Stelle (`TalentService.validate_allocation`).

„Niedrigere Tiers“ statt „alle Punkte im Baum“: Beides ist „Punkte in diesem Baum“, aber nur die niedrigeren Tiers
machen eine fertige Verteilung reihenfolgeunabhängig prüfbar (Laden, Presets, Trials). Sonst könnte ein Tier sich mit
den eigenen Punkten selbst offen halten.

## 4. Gewählte Tier-Schwellen

| Tier | 1 | 2 | 3 | 4 (Endtalent) |
|---|---|---|---|---|
| Punkte in niedrigeren Tiers desselben Baums | **0** | **5** | **18** | **30** |
| Rangkapazität darunter (Runemaster / übrige) | – | 10 / 12 | 24 / 26 | 36 / 38 |
| Anteil, der Pflicht ist (übrige Bäume) | – | 42 % | 69 % | 79 % |

Begründung, jeweils aus den Randbedingungen abgeleitet (56 Punkte auf Level 60, 1 Punkt ab Level 5):
- **Tier 2 = 5**: höchstens die Hälfte der kleinsten Tier-1-Kapazität (Runemaster 10) → echte Wahl in Tier 1
  (z. B. 5 Ränge in einem Passive oder Skill + 4 Ränge verteilt). Gleich der alten ersten Schwelle.
- **Tier 3 = 18**: die kleinste Schwelle, bei der Tier 3 in höchstens **zwei** Bäumen erreichbar ist
  (3 × 19 = 57 > 56) - so bleiben Spezialisierungen spürbar, ein Alles-in-allem-Build kann nicht jede späte Stufe
  öffnen. Nach oben begrenzt durch 20 (Kompatibilität, Abschnitt 7).
- **Endtalent = 30**: unverändert. Hält „höchstens ein Endtalent pro Build“ (2 × 31 = 62 > 56; ab 28 gilt das) und
  alle bisherigen Endtalent-Builds gültig.
- Tier 2 ist in allen drei Bäumen gleichzeitig erreichbar (3 × 6 = 18 ≤ 56) - Hybride bleiben möglich.

Beispiel-Builds mit 56 Punkten: Endtalent A (31) + Tier 3 in B (19) + 6 in C · zweimal Tier 3 (38) + 18 frei ·
dreimal Tier 2 + Rest verteilt.

## 5. Geänderte Daten / Talente / Prereqs

Eine deterministische Umsortierung, keine neuen Talente, keine Werte geändert:
**alter Tier t → neuer Tier ⌈t / 2⌉** (alt 1+2 → 1, 3+4 → 2, 5+6 → 3, 7 → 4). Spalten: Knoten aus dem ungeraden alten
Tier behalten Spalte 0/1, aus dem geraden alten Tier rücken sie auf 2/3. Endtalent Spalte 0 (allein, mittig).

| Baum | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
|---|---|---|---|---|
| Berserker | Seething Blood 5, Hot Temper 3, Relentless 3, Whirlwind [A] | Bloodlust 5, Cyclone [T]*, Frenzied Pace 5, Momentum 3 | Unstoppable 3, Furious Cleave [T], Bloodrush 5, Savage 3 | Unbound Fury [A] |
| Warbreaker | Heavy Hands 5, Thick Skin 3, Crushing Finish 3, Earthshaker [T] | Breaker 5, Concussive Rush [T], Iron Will 5, Overpower 3 | Aftershock 3, Titan's Grip [T], Bulwark 5, Juggernaut 3 | Worldbreaker [T] |
| Bloodblade | Serrated Edge 5, Open Veins 3, Hemorrhage 3, Blood Frenzy [A] | Sanguine 5, Lacerating Strike [T], Bloodletter 5, Thin the Herd 3 | Deep Cuts 3, Rending Rush [T], Exsanguinate 5, Blood Price 3 | Blood Oath [T] |
| Elemental Weaver | Cold Focus 5, Frostbite 3, Elemental Attunement 3, Shatterbolt [T] | Glacial Ward 5, Frozen Pulse [T], Hypothermia 5, Permafrost 3 | Cold Snap 3, Ice Lance [T], Winter Mind 5, Brittle 3 | Winter's Grasp [T] |
| Runemaster | Inscribed 5, Glyph Lore 1, Resonant Marks 3, Arcane Rift [A] | Detonation 5, Sigil of Binding [T], Mana Flow 5, Echoing Marks 3 | Runic Precision 3, Grand Rift [T]*, Arcane Reservoir 5, Mark of Ruin 3 | Glyph Cascade [T] |
| Astral Scholar | Studious 5, Clarity 3, Focused Mind 3, Astral Lance [A] | Star Shards 5, Lance of Stars [T]*, Astral Insight 5, Overflow 3 | Empowered Study 3, Pulse Barrage [T], Deep Reserves 5, Stellar Precision 3 | Astral Ascension [A] |
| Assassin | Precision 5, Keen Eye 3, Cold Blood 3, Marked for Death [T] | Opportunist 5, Guillotine [T], Lethality 5, Swift Kill 3 | Ruthless 3, Exposing Strike [T], Assassin's Focus 5, Killing Edge 3 | Death Mark [A] |
| Bladestorm | Quick Hands 5, Flurry 3, Focused Strikes 3, Blade Fan [A] | Serrated Knives 5, Fan of Knives [T]*, Tempo 5, Riposte Rhythm 3 | Whirling Steel 3, Piercing Blades [T]*, Endless Flurry 5, Bloodied Steel 3 | Thousand Cuts [T] |
| Night Hunter | Shadow Affinity 5, Light Feet 3, Ambush 3, Smoke Veil [A] | Nightstalker 5, Choking Smoke [T]*, Unseen 5, Vanish 3 | Dusk Blade 3, Phantom Step [T], Patient Hunter 5, Deep Shadows 3 | Nightfall [T] |

Zahl = Max-Rang (ohne Zahl: 1) · [A] Aktiv-Skill · [T] Transformation · * hat eine Parent-Voraussetzung.

Prerequisites: alle 6 bleiben unverändert (Kategorie „direktes Upgrade“); sie liegen weiterhin im selben Baum
und einen Tier tiefer als ihr Parent (Grand Rift, Piercing Blades: zwei Tiers). Entfernt wurde kein Parent, weil es
keinen anderen gab - die Freiheit kommt aus den breiteren Tiers und den niedrigeren Schwellen.

## 6. Skills, Passives, Endtalente

- **Aktive Skills** (Whirlwind, Blood Frenzy, Arcane Rift, Astral Lance, Blade Fan, Smoke Veil) sitzen jetzt in
  Tier 1 ihres Baums - die Identität der Spezialisierung ist eine frühe Entscheidung statt einer Pflichtstation.
  Freischaltung unverändert über `unlocks_skill` / `SkillBook`.
- **Transformationen** verteilen sich auf Tier 1–3 (je eine pro Tier und Baum, wie vorher eine pro altem Doppel-Tier);
  Upgrades eines Skills brauchen weiter dessen Talent.
- **Passives** tragen die Breite: je Tier drei der vier Plätze (5er-, 3er-Ränge).
- **Endtalente** bleiben der späte Höhepunkt: allein in Tier 4, 30 Punkte im Baum, höchstens eines je Build, keine
  Parent-Voraussetzung. Aktiv-Endtalente (Unbound Fury, Astral Ascension, Death Mark) bleiben aktiv, die übrigen
  Transformationen.
- Keine Werte, Ränge, Effekte, Kosten oder Cooldowns geändert.

## 7. Save / Kompatibilität

- **Save v15 unverändert, keine Migration.** Gespeichert werden nur Knoten-IDs → Ränge; IDs, Ränge und Bäume sind
  gleich geblieben. Talentpunkte werden weiter aus dem Level abgeleitet (nie gespeichert).
- **Jede alte gültige Verteilung bleibt gültig** (Beweis über die Umsortierung): Ein Knoten im neuen Tier k ≥ 2 kam
  aus dem alten Tier 2k − 1 oder 2k. Die neuen niedrigeren Tiers sind genau die alten Tiers < 2k − 1.
  - alter Tier 2k − 1: verlangte schon 10 (k − 1) Punkte genau dort (10 / 20 / 30 ≥ 5 / 18 / 30);
  - alter Tier 2k: verlangte 5 (2k − 1) Punkte in Tiers < 2k. Ist der alte Tier 2k − 1 belegt, gilt der vorige Fall;
    sonst liegen alle 5 (2k − 1) ≥ 10 (k − 1) Punkte schon in den neuen niedrigeren Tiers.
  - Prerequisites, Ränge und Punktesumme sind unverändert. Deshalb trägt die Tier-3-Schwelle höchstens 20.
- Damit greift `TalentService.sanitize_build` bei alten Spielständen nicht (kein Zurücksetzen, keine Warnung);
  Presets und die drei Trial-Builds bleiben ebenso gültig.
- Respec, Klassenwechsel, Presets: unveränderte Regeln/Code; neue Verteilungen, die die alten Regeln abgelehnt
  hätten (z. B. Fan of Knives mit 6 Punkten im Baum), sind jetzt erlaubt - nur in diese Richtung ändert sich etwas.
- Ein Spielstand dieser Version in einer **älteren** Spielversion könnte solche neuen Verteilungen dort als ungültig
  zurücksetzen (Downgrade wird nicht unterstützt, wie bisher).

## 8. Geänderte Dateien

| Datei | Änderung |
|---|---|
| `data/progression/talent_rules.tres` | `tier_points` = (0, 5, 18, 30) |
| `data/talents/*.tres` (9) | nur `tier` / `column` der Knoten (Umsortierung oben) |
| `scripts/rpg/talents/talent_rules.gd` | `TIERS = 4`, `COLUMNS = 4`, Standard-Schwellen, Kommentar |
| `scripts/rpg/talents/talent_node_definition.gd` | Tier 1–4, `is_capstone` = letzter Tier, Kommentare |
| `scripts/rpg/talents/talent_tree_definition.gd` | Datenprüfung: Schwellenzahl = `TIERS`, Spalte 0–3, Meldung „tier 4 capstone“ |
| `scripts/rpg/talents/talent_service.gd` | nur Kopfkommentar (Regeln unverändert) |
| `scripts/ui/talent_layout.gd` | `TIERS` aus `TalentRules`, Spaltenbreite (4 Plätze), Knotengröße passt in die Spalte |
| `scripts/ui/talent_tree_view.gd` | x-Position aus Spalte 0–3; **keine angedeuteten Pfadlinien** mehr, nur echte Voraussetzungen; Tier-Bänder aus `TIERS` |
| `scripts/ui/talent_tier_scale.gd` | Kommentar |
| `scripts/ui/class_station_panel.gd` | `_restore_tree_scroll`: Scrollposition nach dem Lernen erst setzen, wenn der Bereich sie tragen kann (der kürzere Baum passte bei 200 % kurzzeitig ganz) |
| `tests/unit/test_talent_structure.gd` | **neu** (echte Daten) |
| `tests/integration/test_talents.gd` | synthetische Testklasse im neuen Layout, neue Fälle (freie Wahl, Tier 3 in max. zwei Bäumen) |
| `tests/integration/test_class_ui.gd` | gesperrter Knoten jetzt Tier 2, vier Tiers, Reihe aus vier, keine Pfadlinien |
| `tests/integration/test_warrior.gd` | `_fill` mit neuen Tier-Nummern |
| `docs/TALENT_SYSTEM.md`, `CLAUDE.md` | Regeln nachgezogen; dieser Bericht |

Nicht angefasst: `project.godot`, `settings.cfg`, `docs/Design/`, `docs/tasks/`, Spielstände, UI-Assets, Skill-Icons,
Weapons-Tab, Quests, Bosse, Loot, Crafting, Equipment, Save-Version. Keine Git-Schreibaktionen.

## 9. Gezielte Testergebnisse (Efficient Testing 1.1)

| Lauf | Ergebnis |
|---|---|
| `talent_structure`, `talents` | 18 / 18 grün |
| Gegenprobe: Tier-3-Schwelle testweise 21 | `test_old_builds_stay_valid` und `test_rules_and_tree_shape` schlagen wie erwartet fehl (Deep Cuts); Wert sofort zurückgesetzt |
| `class_ui, warrior, arcanist, shadowrunner, presets, skills, prologue, class_combat_polish` | 63 grün, 2 rot: `class_ui` Scrollposition bei 200 % (behoben, danach `class_ui` 9 / 9 grün) und `test_prologue::test_migration_v3_to_v4` (Item-Dict hat zusätzlich `rarity` - Item-/Save-Migration, nicht Talente; nicht gegen den Stand vor diesem Batch geprüft) |
| `talents, skills` nach letzter Testanpassung | 20 / 20 grün |
| `main_window_layout, ui_tab_geometry, ui_layout, ui_window_foundation, save_foundation, stash` | 32 grün, 1 rot: `test_ui_layout::test_inventory_scrolls_instead_of_overflowing_at_150_percent` (Inventar, nicht Talente; nicht gegen den Stand vor diesem Batch geprüft) |
| `tools/check_project.ps1` | OK (Import + 300 Frames, keine Fehler/Warnungen) |
| `ui_gallery` `talents, talents_full, talents_shadowrunner` 1080p / 100 % und `talents_full, talents_arcanist` 720p / 150 % | 15 Checks OK, Bilder angesehen: vier Plätze je Zeile, keine Überlappung, Punkte je Baum sichtbar |

`test_talent_structure` prüft: Regeln und Baumform (4 / 4 / 4 + 1, eigene Plätze), nur 6 Upgrade-Prereqs, Tier 1
offen ab dem ersten Punkt und jeder Tier-2-Knoten über verschiedene Tier-1-Wege, Aktiv-Skill-Freischaltung,
Upgrade braucht Parent trotz offenem Tier, Endtalent bei 29 gesperrt / 30 offen, Transformations-Endtalent,
nie zwei Endtalente, 450 zufällige alte Builds (Seed fest) unter neuen Regeln gültig, volle Bäume, Trial-Builds,
Speichern/Laden (v15, keine Warnungen, gleiche Punkte), Klassenwechsel, Respec (nur eine Klasse, Skill weg, Punkte zurück).

## 10. Offene Risiken / Designfragen

- **Tempo:** Signature-Skills ab dem ersten Talentpunkt (Level 5 statt bisher frühestens Level 9), späte Passives
  ab 18 statt 20–25 Punkten. Die Summe der Punkte und alle Werte sind gleich, aber die Kurve ist früher - im
  Playtest prüfen (u. a. Skill-Slots: Level-5-Charakter hat schon 3 Basis-Skills).
- **Tier-3-Schwelle 18 vs. 20:** 20 wäre näher am alten Tempo und weiter kompatibel, ließe aber weniger Spielraum
  (Pflichtanteil 77 %). 16 erlaubte Tier 3 in allen drei Bäumen. Entscheidung des Projektleiters erwünscht.
- **Tier-1-Breite der Runemaster:** Glyph Lore hat 1 Rang → Tier-1-Kapazität 10; 5 Punkte sind dort genau die Hälfte.
- **Visuelle Anordnung (für das Redesign):** Upgrade-Linien kreuzen (Aktiv-Skill in Spalte 3, Upgrade in Spalte 1);
  Namen bei vier Plätzen je Zeile gekürzt (Tooltip zeigt den vollen Namen). Bewusst nicht in diesem Batch gelöst.
- Kein Talent mit `required_class_level`; die Regel kommt ohne Sonderfälle aus.

## Screenshot: nur Inspiration

Übernommen als **Richtung**: drei Spezialisierungen nebeneinander, vertikale Tiers als Fortschritt, sichtbare Punkte je
Spezialisierung (gab es schon: „n points invested“), mehrere Wahlmöglichkeiten pro Zeile, Freischaltung über Punkte im
Baum. Bewusst **nicht** übernommen: Layout, Anzahl Zeilen/Spalten und Positionen, Pfeile/Abhängigkeitsketten,
konkrete Talente, Texte, Punktschwelle pro Zeile (dort fest 5 je Zeile; hier 0 / 5 / 18 / 30 aus den eigenen Daten
abgeleitet), Rang-/Kostenregeln und alle übrigen Regeln des Vorbilds. Alle Talente und Werte stammen aus den
bestehenden Daten.
