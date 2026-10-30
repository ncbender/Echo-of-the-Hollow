# Chapter 1 – Guaranteed Rare Reward Relocation 1.0

Content-Korrektur: Das garantierte Rare-Ausrüstungsteil von Kapitel 1 gehört dem Kapitel-Endboss
**Rootbound Sentinel** (Warden's Rest). Der optionale **Grove Warden** (Whisper Forest) vergibt keine
garantierte Rare mehr. Die Garantie wurde verlagert, nicht verdoppelt. Kein Balancing, keine Save-Migration
(Save v15 unverändert).

## Alte Platzierung (Grove Warden Rare R2, `docs/GROVE_WARDEN_RARE_R2.md`)

- `WardensCache` (Whisper Forest, `(900, 560)`) war ein `BossRewardCache` mit
  `boss_id = whisper_forest_grove_warden` und `loot_table = data/loot/grove_warden_rare_reward.tres`.
- Der Cache enthielt ausschließlich die Rare (kein Material). Die festen Boss-Drops des Grove Warden
  (1 Hollow Essence, 2 Iron Ore, 25 Gold) liegen davon unabhängig am Boden und sind unverändert.
- Flags: `defeated.whisper_forest_grove_warden` (GameMap, echter Kill) und
  `boss_reward.whisper_forest_grove_warden` (gesetzt nur von `BossRewardService.claim`, direkt nach dem Item).
- Der Cache stellte die Meilenstein-Speicherung des Warden-Kills; der Sentinel speicherte selbst
  (`defeat_milestone = true`).

## Neue Platzierung

| | Grove Warden (optional) | Rootbound Sentinel (Kapitel-Endboss) |
|---|---|---|
| Knoten | `WhisperForest/WardensCache` (`StoryPickup`, Ort unverändert) | `WardensRest/SentinelCache` (`BossRewardCache`, `(100, 128)`) |
| Inhalt | 2 × `iron_ingot` (vorhandenes Material) | eine Rare aus `grove_warden_rare_reward` (unverändert) |
| sichtbar wenn | `defeated.whisper_forest_grove_warden` und nicht `boss_reward.whisper_forest_grove_warden` | `defeated.wardens_rest_rootbound_sentinel` und weder `boss_reward.wardens_rest_rootbound_sentinel` noch `boss_reward.whisper_forest_grove_warden` |
| Claim-Flag | `pickup.whisper_forest_wardens_cache` | `boss_reward.wardens_rest_rootbound_sentinel` |
| Meilenstein-Save des Kills | `GroveWarden.defeat_milestone = true` | durch den Cache (`Sentinel.defeat_milestone = false`) |

- Der Sentinel's Cache liegt in der Arena, 128 px südlich des Sentinels, gespiegelt zum Split Watchstone
  (`(100, -128)`), abseits der Südlücke zur Kaserne (x 168–232); Area2D ohne Kollision, blockiert nichts.
- Split Watchstone, `AfterSentinel`, Quests, Gates, Ausgänge, Kartengrößen, Fog und Marker unverändert.
  Der Cache meldet kein Story-Ereignis; der Claim ist keine Questvoraussetzung.

## Item-Generierung

Unverändert die bestehende Pipeline: `BossRewardService.claim` → (alle Prüfungen) → genau ein
`EquipmentLoot.roll(grove_warden_rare_reward, …)` → `ItemCreation.generate`: Rare (`rarity_weights {2: 100}`),
Item-Level 20, zwölf Modelle, Affix-Tiers T5 75 % / T4 25 %, Herkunft `found`. Gewürfelt wird erst beim
Claim, nie beim Kill. Die Tabelle behält ihre ID `grove_warden_rare_reward` (Quelle, keine neue Item-ID).

## Code

- `BossRewardService.is_claimed/has_claim/can_claim/claim` nehmen optional `taken_flags`: weitere Flags,
  die als „Belohnung bereits genommen“ zählen. Default leer = bisheriges Verhalten.
- `BossRewardCache.taken_flags` (Export) reicht sie durch. Der Sentinel's Cache trägt
  `[boss_reward.whisper_forest_grove_warden]`.
- Der Warden's Cache nutzt den vorhandenen `StoryPickup` (Prüfung `room_for` vor dem Hinzufügen, Flag erst
  nach dem Item) mit einer `StoryCondition` (required/forbidden flags).

## Alte Saves (v15) – Zustände und Regel

`boss_reward.whisper_forest_grove_warden` wird ab jetzt nie mehr gesetzt; es ist ein eingefrorener Beleg
„die alte Kapitel-Rare wurde bereits genommen“. Damit sind alte und neue Stände eindeutig unterscheidbar.

| Fall | Flags im Save | Verhalten |
|---|---|---|
| A Warden besiegt, Cache nicht geöffnet | `defeated.grove_warden` | Warden's Cache gibt 2 Iron Ingot; die Rare wartet am Sentinel (nicht verloren) |
| B Rare bereits genommen | `defeated.grove_warden` + `boss_reward.grove_warden` | Item bleibt; Warden's Cache geschlossen; Sentinel's Cache geschlossen (keine zweite Rare) |
| C Sentinel besiegt, Watchstone offen | `defeated.sentinel` | Sentinel's Cache beim Betreten offen; Watchstone/Quest unverändert |
| D The First Signs abgeschlossen | `defeated.sentinel` + Quest `completed` | Sentinel's Cache offen (Warden's Rest bleibt über die Chapel erreichbar); Quest bleibt abgeschlossen |
| E keiner besiegt | – | beide Caches versiegelt |

Nichts wird entfernt oder zurückgesetzt; keine Migration.

### Bekannte Kompatibilitätsgrenzen

- **Fall A:** Wer den Warden besiegt, aber den alten Rare-Cache nie geöffnet hat, bekommt jetzt die
  2 Iron Ingot zusätzlich und die Rare erst beim Sentinel (statt sofort im Wald). Kein Verlust, keine zweite
  Rare; die Ingots sind die normale neue Warden-Belohnung. Eine „sofort im Wald“-Zuordnung ist ohne
  Migration nicht unterscheidbar von neuen Spielständen und wurde bewusst nicht geraten.
- **Fall B:** Spieler mit alter Rare erhalten die neue Material-Belohnung des Warden's Cache nicht (sie haben
  den Cache bereits geöffnet).
- Ein `BossRewardService.claim` ohne `taken_flags` (nur Tests/Altaufrufe) kennt die Legacy-Regel nicht; der
  einzige Spiel-Aufrufer ist `BossRewardCache`.

## Atomarität / Volle Tasche

- Sentinel: alle Prüfungen (besiegt, nicht genommen, kein Trial, Platz für jedes Modell) vor dem Wurf; Item in
  die Tasche, erst dann das Flag, in einem synchronen Aufruf. Volle Tasche/Trial: kein Wurf, kein Flag, Cache
  bleibt. Kein Flag ohne Item; kein zweiter Wurf durch erneutes Interagieren. Ein abgelehnter Versuch würfelt
  nichts – es gibt also kein „vorgewürfeltes“ Item, das gleich bleiben müsste; das genommene Item wird nie neu
  gewürfelt (Save/Load hält Affixe).
- Warden: `room_for(iron_ingot) < 2` → „Your pack is full.“, nichts geändert.
- Meilenstein-Saves: je einer nach dem Kill (beide Bosse), einer nach dem Sentinel-Claim.

## Tests

`tests/integration/test_chapter_1_rare_reward.gd` (16, ersetzt `test_grove_warden_reward.gd`): Platzierung
und Daten, Erreichbarkeit (Strahlen ohne Wand, Platz am Cache) und echter Interaktionsabstand (12 px aktiv,
40 px nicht), kein Claim vor dem Kill, genau eine Rare, volle/teilweise volle Tasche, Trial, fehlgeschlagene
Übergabe, Save vor/nach Claim, echter Sentinel-Kill mit Meilensteinen und Loot-Feed, Warden ohne Rare
(Ingots, Meilenstein), volle Tasche beim Warden, synthetische Altstände A–E. Angepasst:
`test_whisper_forest_target_fix`, `test_world_expansion_a`, `test_world_expansion_b`, `test_roots_remember_m3`.
Unverändert grün mitgelaufen: `test_roots_remember_m4`, `test_quest_turnin_mara`, `test_quest_turnin_t1`.
Kein manueller Fenster-Playtest.
