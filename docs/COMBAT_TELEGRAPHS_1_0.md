# Combat Telegraphs 1.0 – Batch 3B

Die Angriffsvorbereitung (Startup) jedes Gegnerangriffs zeigt jetzt, wie er abgewehrt werden kann: parierbar, nur
blockbar oder weder noch. Grundlage sind allein die vorhandenen `defense_flags` und die echte Auswertung in
`DefenseComponent.resolve`. Keine Änderung an Hitboxen, Reichweiten, Phasenzeiten, Parry-Fenstern, Blockregeln,
Cooldowns, Schaden, Gegnerwerten, KI, Angriffsdaten, Save (v15), Loot-Feed oder Menüs. Keine PNGs, keine Sounds.

## 1. Tatsächliche Verteidigungsregeln und Zuordnung

Auswertung `DefenseComponent.resolve` (geprüft, Verhalten unverändert):
1. Weder Blockable noch Parryable → Tag `unblockable`, keine Abwehr.
2. Im Parry-Fenster, Angriff **Parryable**, Winkel im Parry-Bogen → **pariert** (unabhängig von Blockable).
3. Sonst nur, wenn das Profil blocken kann, der Angriff **Blockable** ist und der Winkel im Block-Bogen liegt:
   - mit **Guard Breaking** → **Guard Broken** (keine Schadensreduktion, Erholungszeit) – der Block hält nicht;
   - ohne → **geblockt** (Schaden, Rückstoß, Reaktion reduziert).

Guard Breaking ist also **nicht** „unblockbar“: der Block trifft den Angriff, bricht aber. Für die Anzeige zählt, ob
eine Abwehr wirklich gelingt.

Gemeinsame Abfrage (neu in `AttackDefinition`, eine einzige Lesart der Flags): `is_parryable()`, `is_blockable()`,
`breaks_guard()`, `block_holds()` (= blockbar und nicht Guard Breaking), `telegraph_kind()`. `DefenseComponent.resolve`
liest die Flags jetzt über dieselben Methoden (gleiches Verhalten, nur keine zweite Bitprüfung).

| Kategorie (`telegraph_kind`) | Bedingung | Flags (Bitwerte B=1, P=2, G=4) |
|---|---|---|
| **PARRYABLE** | Parryable | 2, 3, 6, 7 (auch parierbar, aber nicht blockbar) |
| **BLOCK_ONLY** | nicht Parryable, Blockable, kein Guard Breaking | 1 |
| **UNDEFENDABLE** | sonst | 0, 4, 5 (blockbar + Guard Breaking ohne Parry) |

Produktive Angriffe (Daten unverändert):

| Angriff | Flags | Kategorie | Nutzer |
|---|---|---|---|
| `grunt_swipe` | 3 | PARRYABLE | Grunt, Hardened Husk, Hollowfang Wolf, Rootbound Husk und weitere Gegner ohne eigene Familie |
| `grunt_slam` | 7 | PARRYABLE (ein Block bricht) | dieselben (Heavy) |
| `warden_swipe` | 1 | BLOCK_ONLY | Grove Warden |
| `warden_slam` | 0 | UNDEFENDABLE | Grove Warden |
| `sentinel_strike` | 3 | PARRYABLE | Rootbound Sentinel |
| `sentinel_root_slam` | 1 | BLOCK_ONLY | Rootbound Sentinel |

Alle drei Kategorien kommen im Content vor; nicht vorkommende Flag-Kombinationen (z. B. 2, 4, 5, 6) prüft der Test mit
Probe-Angriffen, ohne produktive Daten zu ändern.

## 2. Finale visuelle Sprache (`EnemyView`)

- **Fläche (für alle):** Kegel in Angriffsrichtung mit Reichweite und Bogen, Füllung wächst mit dem Startup;
  dünne Linie = leicht, dicke = schwer. UNDEFENDABLE: roter Kegel mit gezackter Kante.
- **Symbol (eines je Angriff, Form + Farbe):**
  - PARRYABLE: heller Kreuzfunke („+“ mit vier Eckglanzpunkten), Pergamentweiß;
  - BLOCK_ONLY: kantiger Schild (flache Oberkante, Spitze unten), Bernstein auf dunklem Bernstein;
  - UNDEFENDABLE: roter gebrochener Ring (vier Bögen mit Lücken) mit Kernpunkt.
  - Jeder Strich mit dunkler Tintenkontur, ganzpixlig, ohne Weichzeichnung.
- **Platz:** über dem Kopf (über dem Lebensbalken) oder unter dem Körper – automatisch die Seite, die weiter von
  der Angriffsrichtung entfernt ist (`symbol_anchor`); das Symbol liegt nie auf dem Kegel (Test über 16 Richtungen).
- **Zeitlogik (gleich für alle):** wächst in den ersten 15 % des Startups ein, bleibt stehen, wird ab 70 % einmal
  heller. Kein Blinken: das frühere Körperflackern (~6 Hz) ist durch einen ruhigen Anstieg mit dem Startup ersetzt,
  das Pulsieren des Unblockable-Rands entfällt.
- **Ende:** gezeichnet nur im Zustand TELEGRAPH (`EnemyView.current_telegraph()`); aktive Phase, Stagger,
  Unterbrechung und Tod beenden es sofort – nichts bleibt zurück.
- **Entfernt:** der Welttext „!!“ über unblockbaren Angriffen. Der vorhandene Warnton `unblockable_warn` bleibt.

## 3. Entfernung des Parry-Texts

- `Player._on_parried` erzeugt kein „PARRY“ mehr. Erfolgsfeedback bleibt: Stern (STAR) und Lichtblitz (FLASH) am
  Verteidigungspunkt, Parry-Sound, Aufblitzen des Gegners (`EnemyView._on_parried`) und seine Unterbrechung/Benommenheit
  (`EnemyConfig.parry_daze`). Ein zusätzlicher Akzent war nicht nötig.
- Keine Parry-Cooldown-Anzeige (seit Batch 3A entfernt, nicht wieder eingeführt). Dash und HUD unverändert.

## 4. Sichtprüfung der finalen Mastery-Raute (aus Batch 3A)

Echtes Godot-Fenster, 1920 × 1080, 100 %:
- `hud_level_mastery_dash`: Raute zentriert am Körper des Helden, oberhalb der Dash-Segmente mit sichtbarem Abstand
  (auch bei voller Ausdehnung), keine Überdeckung mit Namen oder Lebensbalken.
- `hud_level_both` (Hero und Mastery in einem Moment): zuerst goldener Ring und Hero-Meldung; die Mastery-Meldung und
  ihre Raute warten – keine Überlagerung.
- Befund: keine Korrektur nötig.

## 5. Ausgeführte Tests (automatisiert)

- `./tools/check_project.ps1`: **Startup check OK**.
- Neu `test_combat_telegraphs` (4 Tests): alle 8 Flag-Kombinationen gegen die echte `resolve`-Auswertung (Parry-
  und Block-Zustand), Guard Breaking ≠ unblockbar, parierbar ohne blockbar; die 6 produktiven Angriffe (Flags
  unverändert, Kategorie); echter Grunt: nichts beim Verfolgen, Symbol im Startup, weg nach dem Startup, bei
  Stagger und Tod; Symbol nie auf der Angriffsfläche (16 Richtungen, beide Warden-Angriffe).
- `-Suite "combat_telegraphs,combat_feedback,defense,enemy"`: **26 passed, 1 failed** im ersten Lauf (Testfehler:
  Gegner startete in Reichweite) → korrigiert, `combat_telegraphs` danach **4 passed**.
- `-Suite "roots_remember_m3,whisper_forest_target_fix,hit_reaction,hits"`: **41 passed, 0 failed**.
- Angepasst: `test_combat_feedback` (Parieren zeigt keinen „PARRY“-Text, Stern und Blitz erscheinen).
- Keine Full-Suite, keine Gameplay-Loops, kein Asset-Validator (keine PNGs geändert).

## 6. Selbst angesehene Screenshots (1920 × 1080, 100 %)

- `hud_telegraphs`: drei Gegner spät im Startup, eingefroren – links Grunt-Swipe (Kreuzfunke), rechts Warden-Swipe
  (Schild), unten Warden-Slam (roter gebrochener Ring, gezackter roter Kegel; Symbol unter dem Körper, da der
  Angriff nach oben zielt). Galerie-Kopien der Grunt-Konfiguration erzwingen nur leicht/schwer.
- `hud_telegraph_fight`: kurzer echter Kampf mit Grunt, Hardened Husk und Hollowfang Wolf (alle Grunt-Angriffe →
  Kreuzfunke über dem Kopf, Kegel frei).
- `hud_level_mastery_dash`, `hud_level_both`: siehe Abschnitt 4.
- Galerie-Läufe der beiden Telegraph-Ansichten zuerst mit Fehlschlag „window open“ (Name ohne `hud_`-Präfix), nach
  Umbenennung **OK**; die fehlgeschlagenen Aufnahmen zählen nicht.

## 7. Vorschlag: Angriffsmix des Hardened Husk (nur Befund, nichts geändert)

- **Ist:** Der Husk (`hardened_husk.tres`, Rang Elite = nur Darstellung) hat keine eigene Angriffsfamilie und nutzt
  die Grunt-Familie aus `scenes/enemies/grunt.tscn`: `grunt_swipe` (3) und – mit `heavy_attack_interval = 2` jeder
  zweite Angriff – `grunt_slam` (7). Beide sind **parierbar**; ein Mix existiert nicht.
- **Ungenutzte Varianten:** `warden_swipe` (1) / `warden_slam` (0) sind Boss-Angriffe mit Boss-Werten (Schaden,
  Reichweite, Startup) – als Husk-Angriffe ungeeignet.
- **Getrennte Konfiguration:** möglich, ohne Grunt-Daten anzufassen – `Enemy.attacks` (WeaponFamily) ist je platziertem
  Gegner bzw. je `spawn_enemy`/`Encounter` setzbar (so bekommen Warden und Sentinel ihre Familien).
- **Kleinste Änderung:** neue Familie `data/enemies/hardened_husk_attacks.tres` = Kopie der Grunt-Angriffe mit eigenen
  IDs; nur der schwere Angriff erhält andere `defense_flags` (z. B. 1 = nur blockbar oder 5/0 = weder noch). In den
  Karten mit Husk (`old_road.tscn`, `tangled_wood.tscn`, `whisper_forest.tscn`) `attacks = …` an den Husk-Knoten
  setzen. Alternative ohne Kartenänderungen: ein optionales `EnemyConfig.attacks`, das `Enemy._ready` nutzt, wenn
  der Knoten keine Familie gesetzt hat (kleine Codeänderung, eine Stelle).
- **Betroffene Tests:** `test_combat_telegraphs` (Liste der produktiven Angriffe), `test_enemy`, `test_defense`,
  `test_world_expansion_a/b` und `test_hollowwood_loot` (Husk-Platzierungen), ggf. ein neuer Fall „Husk wechselt
  zwischen Kreuzfunke und Schild/Ring“.
- **Designentscheidungen nötig:** (1) Welcher Husk-Angriff wird nicht parierbar – der schwere Slam (naheliegend)?
  (2) Nur blockbar (Schild) oder weder noch (roter Ring)? (3) Familie je Platzierung oder als Standard der Konfiguration?
  (4) Bleiben Schaden und Timing exakt wie beim Grunt (empfohlen für einen reinen Lesbarkeitstest)?

## 8. Commit

Siehe unten (nachgetragen).

## Offene Punkte für die gemeinsame Abnahme

1. Lesbarkeit der Symbole im Kampfgetümmel und auf hellem/dunklem Boden; Symbolgröße (~12 px) bei 100 %.
2. `grunt_slam` (Parry + Guard Breaking) zeigt den Kreuzfunken; dass ein Block bricht, sagt die Anzeige nicht.
3. Roter UNDEFENDABLE-Kegel vs. früher violett; der rote Lebensbalken liegt in der Nähe.
4. Warnton `unblockable_warn` nur bei `is_unblockable()` (Flags 0 und 4), nicht bei 5 (blockbar + Guard Breaking) – unverändert übernommen.
5. Kampflesbarkeit und Spielgefühl lassen sich aus Tests und Standbildern nicht abschließend beurteilen.
6. 75/125/150 % beim Entwickler.
