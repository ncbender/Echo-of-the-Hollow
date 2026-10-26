# Progression – Waffenbeherrschung & XP

Status-Legende: ✅ implementiert · 🟡 teilweise · 🔧 nur vorbereitet · ⬜ offen

## Waffenbeherrschung ✅
- Fortschritt gehört dem **Charakter**, nicht der Klasse (`Character.mastery: WeaponMastery`).
- Pro Waffenfamilie: Level (1–20), XP im aktuellen Level, XP bis zum nächsten Level, freigeschaltete
  Techniken, Meilensteine.
- Daten: `data/mastery/<family>.tres` (`MasteryTrack`): `max_level`, Kurve
  `xp_to_next(n) = round(xp_base · xp_growth^(n-1))` (Startwerte 100 / 1,15), Liste von `MasteryUnlock`.
- `MasteryUnlock.requirement_id` = `AttackDefinition.unlock_requirement` → die Technik wird über den
  **bestehenden Combo-Baum** freigeschaltet (`CombatComponent.set_unlocked`). Ohne Freischaltung
  verhält sich der Knoten wie nicht vorhanden (Combo startet neu) – Basis-Combos sind ab Level 1 spielbar.

| Familie | Technik (Lv 3) | Meilensteine |
|---|---|---|
| Einhandschwert | `sword_light_4_mastery` „Riposte Spin“ (L-L-L-L) | Lv 5, 10, 20 (nur Name) 🔧 |
| Zweihandschwert | `greatsword_light_4_mastery` „Cleaving Echo“ (L-L-L-L, **neu**) | Lv 5, 10, 20 🔧 |

Der neue Zweihand-Knoten ist nur über die Freischaltung erreichbar; bestehende Combos/Timings unverändert.

## XP-Vergabe ✅ (`CombatRewardTracker`, Werte vorläufig in `data/progression/progression_rules.tres`)
| Ereignis | Beherrschung | Klasse |
|---|---|---|
| akzeptierter Treffer | 4 | 1 |
| + Finisher (`finisher`-Tag) | +6 | – |
| + voll geladener Heavy | +4 | – |
| Gegner besiegt (`EnemyConfig`) | 20 | 30 |

**Exploit-Schutz**
- Nur `hit_landed` (akzeptierte Treffer) zählt – Klicks ins Leere geben nichts.
- Ein Belohnungs-Schlüssel pro (Schwung, Ziel); doppelte Ereignisse werden ignoriert.
- Trainingsziele (Gruppe `training_target`): 50 % XP, max. 60 XP pro Ziel-Instanz und Sitzung, kein
  Kill-XP. Nach Arena-Neuladen beginnt der Deckel neu (bewusst: Sitzungsdeckel; Puppen bleiben langsam).
- Kill-Belohnung einmal pro Ziel-Instanz.

## UI ✅
Beherrschungsfenster oben rechts (Familie der aktuellen Waffe, Level, XP-Balken, nächste Freischaltung,
Techniken) + Meldungen bei Level-up/Freischaltung. Debug: **F3** +100 XP für die aktuelle Familie.

## Offen
- ⬜ Progressionsgeschwindigkeit balancieren (Werte sind Platzhalter).
- 🔧 Meilensteine haben noch keinen Spieleffekt.
- ⬜ Weitere Familien (Äxte, Dolche, Speere …): neue `WeaponFamily` + `MasteryTrack` – kein Code nötig.
