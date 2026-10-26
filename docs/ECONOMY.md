# Hollowwood Loot Economy 1.0 – kontrollierte Grundlage

Status: datengetriebene Grundlage und Simulation. Bewusst **keine** Balance-Änderung, weil Basiswerte und
Goldmengen im Design noch fehlen.

## Umgesetzt
- **Verkaufswert:** `EconomyService.unit_value` = `ItemDefinition.base_value` × `rules.rarity_sell_factors`
  (Normal 1,0 · Magic 1,6 · Rare 2,5 · Epic 4,0 · Legendary 7,0, provisorisch), abgerundet, je Stück.
  - Unique/Set: nur ihr eigener `special_sell_value` (0 = nie verkaufbar), nie Basis × Faktor.
  - Nicht verkauft werden: Gold, Questitems und Items ohne Basiswert („This item has no value yet.“).
- **Verkaufen** (`EconomyService.sell`) als Transaktion:
  - Schutz zuerst (`ItemProtection.destroy_block` mit `allow_special`): ausgerüstet, Preset, Favorit, gesperrt, Quest.
  - Danach Item entfernen und Gold gutschreiben; schnelle Wiederholungen werden abgelehnt.
  - Es gibt **keinen Händler** im Spiel (Trading House nicht restaurierbar). Nur Tests und die Simulation rufen
    `sell` auf.
- **Simulation:** `EconomySimulation.run(db)`; der Bericht steht in `tests/output/economy_report.txt` (aus
  `test_economy`). Geprüft werden:
  - Material: Herstellen → Verwerten gibt nie mehr Rohmaterial zurück, auch beim besten Wurf (40 %).
    Für jedes verwertbare Rezept geprüft.
  - Gold: Gold kann keine Items kaufen (kein Händler). Gold fließt nur ab: Flask-Upgrades, Respec,
    Klassenquests. Damit gibt es keine Goldschleife.
  - XP:
    - Verwerten gibt keine XP.
    - Rüstungs-XP aus Blocks ist je Gegner gedeckelt; Kills zählen einmal pro Gegnerinstanz.
    - Sammel-XP braucht einen verfügbaren Knoten (Echtzeit-Respawn, gespeichert).
  - Erstkill: Ein besiegter persistenter Gegner (Grove Warden) bleibt nach Save/Load weg. Laden gewährt keine
    Belohnung; das Flag liegt im selben Spielstand wie die Beute.
- **Goldquellen heute:** Gegner-Drops aus `EnemyConfig.drops` (Grunt 3, Rootbound Husk 2, Hollowfang Wolf 1,
  Hardened Husk 4, Grove Warden 25). Unverändert.

## Offen (Designwerte fehlen; nicht geraten)
- Basiswerte der Items, deshalb ist derzeit nichts verkaufbar.
- Gegnerränge Elite/Boss und deren Goldmengen. Grove Warden ist als persistenter Gegner faktisch der Boss, hat aber
  keinen Rang.
- Gold aus Quests und Schatztruhen: weder System noch Werte vorhanden.
- Händler/Verkaufsort und ob Verkaufen wie Verwerten eine Bestätigung braucht (Unique/Set).
- Hinweis zur Größenordnung: Alle Flask-Upgrades zusammen kosten 8950 Gold. Ein Grunt bringt 3 Gold.
