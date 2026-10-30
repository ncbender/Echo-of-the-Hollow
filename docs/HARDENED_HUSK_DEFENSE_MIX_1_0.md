# Hardened Husk Defense Mix 1.0 (Abschluss Batch 3B)

Jeder Hardened Husk hat jetzt einen Verteidigungsmix: Der **Swipe bleibt parierbar** (Kreuzfunke), der **schwere
Slam ist nicht parierbar, aber regulär blockbar, ohne Guard Breaking** (bernsteinfarbener Schild). Die Anzeige folgt
weiter allein `AttackDefinition.telegraph_kind()` – kein Sonderfall für den Husk. Grunts, Wölfe und Bosse unverändert.

## Gewählter Konfigurationsweg

- Husks entstehen nicht nur als Kartenplatzierungen, sondern auch über die Warrior-Trial (`trial_warrior.tres`,
  `enemy_configs`), Encounters und `GameMap.spawn_enemy`. Eine Zuweisung je Kartenknoten hätte diese Wege verpasst.
- Deshalb: optionales **`EnemyConfig.attacks: WeaponFamily`** (rückwärtskompatibel, Standard `null`). `Enemy._ready`
  übernimmt es, wenn gesetzt; ohne Wert bleibt alles wie bisher (Szenen-Standard Grunt-Angriffe bzw. die Familie aus
  Platzierung/Spawn, z. B. Warden, Sentinel). Keine Prüfung von Name oder ID.
- Vorrang: Hat eine Konfiguration eine Familie, gilt sie überall, wo diese Variante auftritt. Derzeit setzt nur der
  Hardened Husk eine; keine Husk-Platzierung trägt eine eigene Familie (Test).

## Geänderte Dateien und Husk-Platzierungen

- **Neu:** `data/enemies/hardened_husk_attacks.tres` – Kopie von `grunt_attacks.tres` mit eigenen IDs
  (`husk_claws`, `husk_swipe`, `husk_slam`); einzige inhaltliche Änderung: `husk_slam.defense_flags = 1` (Grunt-Slam: 7).
  `husk_swipe` behält den Standard 3.
- **Geändert:** `scripts/enemies/enemy_config.gd` (Feld `attacks`), `scripts/enemies/enemy.gd` (eine Zuweisung in
  `_ready`), `data/enemies/hardened_husk.tres` (`attacks = …`).
- **Nicht geändert:** `grunt_attacks.tres`, alle anderen Gegnerkonfigurationen, alle Map-Dateien (nicht nötig).
- **Betroffene Husk-Vorkommen (alle über die eine Konfiguration):** `old_road.tscn` (1), `tangled_wood.tscn` (2),
  `whisper_forest.tscn` (1), Warrior-Trial-Finale (`trial_warrior.tres`) sowie jeder Spawn mit `hardened_husk.tres`.
- Der **Sanctum Warden** (Boss der Arcanist-Trial) übernimmt laut `test_class_trials_m31` alle Kampfwerte des Husk;
  er behält als Boss die Grunt-Angriffe (`attacks = null`), der Test vergleicht die Werte ohne `attacks`.

## Unveränderte Kampfwerte und Timings

Husk-Swipe und -Slam sind in jedem gespeicherten Wert identisch mit Grunt-Swipe bzw. -Slam (per Test über alle
Speichereigenschaften inkl. Charge-Profil): Schaden 12 / 20, Poise 10 / 25, Startup 0,45 / 0,7 s, Aktiv 0,1 / 0,12 s,
Recovery 0,5 / 0,7 s, Reichweite 30 / 34, Bogen 100° / 140°, Rückstoß, Hitstop, Lunge, Reaktion, Dash-Cancel-Phasen.
Konfiguration (Leben, Poise, Tempo, `attack_cooldown` 1,2, `heavy_attack_interval` 2 = jeder zweite Angriff Slam),
KI und Reihenfolge unverändert.

## Ausgeführte Tests

- `./tools/check_project.ps1`: **Startup check OK**.
- `test_combat_telegraphs` erweitert (jetzt 8 Tests): Husk-Familie = Grunt-Familie bis auf IDs und Slam-Flags; echte
  Abwehr – Swipe pariert, Slam nicht pariert, Slam geblockt mit derselben Schadensreduktion wie jeder haltende Block,
  kein Guard Break; Husk nutzt seine Familie, Grunt und Wolf behalten die Grunt-Angriffe, ein Boss seine; alle vier
  Kartenplatzierungen ohne eigene Familie, die Trial nutzt dieselbe Konfiguration; produktive Angriffsliste ergänzt.
- `-Suite "combat_telegraphs,defense,enemy,combat_feedback,class_trials_m31,side_quests"`: erster Lauf
  **47 passed, 3 failed** (veraltete Erwartung im Sanctum-Warden-Test, zwei Fehler im neuen Test: Vergleich des
  Charge-Sub-Resources, Parsen der Map-IDs) → behoben; Nachlauf `combat_telegraphs,class_trials_m31` grün,
  `combat_telegraphs` **8 passed**.
- `-Suite "class_trials_m1,class_trials_m3,world_expansion_a,hollowwood_loot,roots_remember_m3,hud,old_road"`:
  **67 passed, 0 failed**.
- Keine Full-Suite, keine Gameplay-Loops, keine Assets (kein Validator).

## Selbst angesehene Screenshots (1920 × 1080, 100 %)

- `hud_husk_mix`: links Husk-Swipe spät im Startup (Kreuzfunke), rechts Husk-Slam (Schild), unten ein normaler
  Grunt-Slam zum Vergleich (Kreuzfunke). Galerie-Kopien der echten Konfigurationen erzwingen nur leicht/schwer.

## Commit

Siehe `docs/COMBAT_TELEGRAPHS_1_0.md` („Hardened Husk Defense Mix 1.0“) und unten (nachgetragen).

## Offen

Menschliche Abnahme von Kampflesbarkeit und Spielgefühl (z. B. ob der Wechsel Kreuzfunke/Schild im Kampf gelesen wird).
