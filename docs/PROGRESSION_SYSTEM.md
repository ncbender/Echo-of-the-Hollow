# Progression – Waffenbeherrschung & XP

Status-Legende: ✅ implementiert · 🟡 teilweise · 🔧 nur vorbereitet · ⬜ offen

## Waffenbeherrschung ✅ (Weapon Mastery 1.4, `docs/WEAPON_MASTERY_COMBAT_FLOW.md`)
- Fortschritt gehört dem **Charakter**, nicht der Klasse (`Character.mastery: WeaponMastery`), für alle
  neun Familien (Level 1–20, XP im Level); Klassenwechsel ändert nichts.
- Daten: `data/mastery/<family>.tres` (`MasteryTrack`): `max_level`, Kurve
  `xp_to_next(n) = round(xp_base · xp_growth^(n-1))` (Startwerte 100 / 1,15, **vorläufig**).
- Ein Level schaltet **nur Combo-Pfade** frei (`WeaponFamily.combo_paths`, Signal
  `WeaponMastery.path_unlocked`): Level 1 = ein Quick- und ein Heavy-Grundangriff; Nahkampf Lv 2/4/6/9/11/14/17/20,
  Bogen Lv 2/4/6/9/14/17/20 + Flowing Draw Lv 10. **Keine passiven Stat-Boni.**
- Die Bridge setzt `CombatComponent.mastery_level` der getragenen Familie; eine Kette behält das Level ihres Starts.
- Die alten Techniken (Riposte Spin, Cleaving Echo) und die Namens-Meilensteine sind mit 1.4 entfallen.

## XP-Vergabe ✅ (`CombatRewardTracker`)
| Ereignis | Beherrschung | Klasse |
|---|---|---|
| akzeptierter Treffer | – (zählt als Beitrag) | 1 |
| Gegner besiegt (`EnemyConfig.mastery_xp_reward`) | aufgeteilt nach Waffenschaden je Familie | `class_xp_reward` |

**Exploit-Schutz**
- Nur `hit_landed` (akzeptierte Treffer) zählt als Beitrag – Klicks ins Leere geben nichts.
- Beherrschungs-XP nur beim Kill, nach Beitrag (nicht pro Treffer, nicht nur der letzte Treffer); ein Kill durch
  Skill/Status zahlt den beteiligten Familien; ohne Waffenbeteiligung keine Beherrschungs-XP.
- Trainingsziele (Gruppe `training_target`) geben **keine** Beherrschungs-XP (Klassen-XP wie bisher nicht).
- Kill-Belohnung einmal pro Ziel-Instanz; Klassen-XP pro (Schwung, Ziel) einmal.

## UI ✅
Spielerrahmen: Familie und Level der getragenen Waffe; Klassenstation, Seite **Weapons**: alle neun Familien mit
Level, XP und ihren Pfaden (Level, Eingabe, Name; freigeschaltet grün); Meldungen bei Level-up und
„Combo unlocked: …“. Debug: **F3** +100 XP für die aktuelle Familie.

## Offen
- ⬜ Progressionsgeschwindigkeit balancieren (Kurve und Kill-XP vorläufig; Ziel laut Design: Hauptfamilie
  etwa Lv 5–8 am Ende von Hollowwood, Lv 20 im Endgame).
- ⬜ Schutz gegen das Farmen trivialer Gegner (es gibt noch keine Gegnerstufen).
