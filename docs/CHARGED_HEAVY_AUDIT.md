# Audit: Charged-Heavy-Abhängigkeiten (vor dem Heavy-Impact-Umbau)

Stand: `dev/gathering-11-final`. Nur Bestandsaufnahme; **nichts davon ist geändert**.
Heavy Impact (gültiger Heavy-Treffer ab Mastery 1, Hauptziel 100 % / weitere Treffer 50 % Zusatzschaden) ist
**nicht umgesetzt**.

**Grundlagen:**
- Altes System: Jeder Heavy konnte per RMB gehalten werden. Stufen: < 250 ms Normal, ab 250 ms Empowered, ab 700 ms Full. „Fully charged“ hieß `hit.charge_tier >= ChargeProfile.max_tier()`, auch beim Grund-Heavy H.
- Heavy-Finisher gab es vor 1.4 schon auf Level 1 über L-L-H (Schwert-Crush, Zweihänder-Whirl).
- Heute (Combat Flow 1.5): keine Aufladung; `charge_tier` ist bei Spielerangriffen immer 0.
  - Seit dem Combat Rework bildet die eine Funktion `HitData.is_full_power()` „voll aufgeladen“ auf **Heavy-Finisher** ab (`flow_role == HEAVY_FINISHER`). Das ist vorläufig.
  - Der erste Heavy-Finisher ist L-L-H auf **Mastery 4** (H-Familien), danach L-H-H Lv 11, H-L-H Lv 14, H-H-H Lv 20.
  - Der Bogen hat kein `heavy`-Tag (P trägt `precision`).
- Prüfstellen: `HitCondition.full_charge_only` (`scripts/rpg/effects/hit_condition.gd:37`), `TaggedHitModifierEffect.full_charge_only` (`tagged_hit_modifier_effect.gd:32`), `EssencePoiseEffect` (`essence_poise_effect.gd:35`) – alle über `is_full_power()`.

## A. Direkt an „voll aufgeladen“ gebunden

| # | Name / Herkunft | Fundstelle | Alte Bedingung | Effekt | Cooldown / Ressource / Proc-Grenze | Heute | Konflikt Mastery 1 |
|---|---|---|---|---|---|---|---|
| A1 | **Overpower** – Warrior, Warbreaker T4 (3 Ränge) | `data/talents/war_warbreaker.tres` (`war_overpower`, ConditionalHitBonus) | Tag `heavy` + voll aufgeladen (jeder Heavy, auch Grund-H) | +8 % Schaden pro Rang | keiner; wirkt **auf jeden Treffer** des Schwungs (pro Ziel) | nur Heavy-Finisher; Text schon auf „Heavy finishers“ geändert | **wirkungslos auf Lv 1–3**; Grund-H qualifiziert nicht mehr (Einschränkung gegenüber alt) |
| A2 | **Worldbreaker** (Capstone) – Warrior, Warbreaker T7: Teil Haltung | ebd. (`war_worldbreaker_poise`, ConditionalHitBonus, Markierung `worldbreaker`) | Tags `heavy`+`finisher` + voll aufgeladen | +30 % Haltungsschaden | keiner; pro Treffer | jeder Heavy-Finisher (Aufladen entfällt) | **wirkungslos auf Lv 1–3** |
| A3 | **Worldbreaker** – Teil Beben | ebd. (`war_worldbreaker`, HitTrigger) | wie A2 | Beben 56 px: 60 % des Trefferschadens an **andere** Gegner (Ziel ausgenommen), 25 Haltung, 10 px Knockback | `once_per_swing`; keine Abklingzeit; Beben-Treffer sind TRIGGERED (keine Rekursion) | wie A2 | **wirkungslos auf Lv 1–3** |
| A4 | **Essence of the Stone Golem** – Essenz (Items, klassenlos) | `scripts/rpg/effects/essence_poise_effect.gd`, `data/crafting/essences/stone_golem.tres` | `heavy`+`finisher` + voll aufgeladen | +60 % Haltung × Essenzstärke | einmal pro (Schwung, Ziel) über alle Träger; kein Cooldown | jeder Heavy-Finisher; Text angepasst | **wirkungslos auf Lv 1–3** |
| A5 | **Stormcaller – Path B „Steadfast“** – Evolution (Item) | `data/crafting/evolutions/stormcaller.tres` (TaggedHitModifier, Tag `heavy` per Standard) | `heavy` + voll aufgeladen (jeder Heavy) | +40 % Haltung (dazu +40 Rüstung als Stat) | keiner; pro Treffer | nur Heavy-Finisher; Text angepasst | Haltungsteil **wirkungslos auf Lv 1–3**; Grund-H qualifiziert nicht mehr |

## B. Heavy-Finisher ohne Aufladebedingung (`heavy`+`finisher`)

| # | Name / Herkunft | Fundstelle | Bedingung | Effekt | Grenzen | Heute | Konflikt Mastery 1 |
|---|---|---|---|---|---|---|---|
| B1 | **Aftershock** – Warrior, Warbreaker T5 (3 Ränge) | `war_warbreaker.tres` (`war_aftershock`) | `heavy`+`finisher` | Nachbeben 30 px: 15 %/Rang des Trefferschadens an andere Gegner, 6 Haltung, 4 px | `once_per_swing`, kein Cooldown | unverändert, Heavy-Finisher | **wirkungslos auf Lv 1–3** (alt: L-L-H auf Lv 1) |
| B2 | **Crushing Finish** – Warrior, Warbreaker T2; **Executioner's** – Affix (Waffen) | Stat `finisher_power`, `character_stat_modifier.gd:23` | Tags `heavy`+`finisher` | +5 %/Rang bzw. +8–30 % Schaden und Haltung | Stat, pro Treffer | unverändert | **wirkungslos auf Lv 1–3** |
| B3 | **Echo Blade** – Legendary | `echo_shockwave_effect.gd`, `data/items/echo_blade.tres` | `heavy`+`finisher` | Schockwelle 52 px: 40 % Schaden an andere, 10 Haltung | `once_per_swing`, 0,5 s Cooldown | unverändert | **wirkungslos auf Lv 1–3** |
| B4 | **Essence of the Storm Wolf** – Essenz | `essence_discharge_effect.gd` | `heavy`+`finisher` | Entladung 44 px: 35 % × Stärke × Schock-Bonus, 6 Haltung, Markierung „charged“ 2 s (für Thunderquake) | einmal pro Schwung über alle Träger, 0,8 s Cooldown | unverändert | **wirkungslos auf Lv 1–3**; Thunderquake-Resonanz damit auch |
| B5 | **Stormcaller – Path A „Storm Charge“** | `stormcaller.tres` (TaggedHitModifier) | `heavy`+`finisher` | +30 % Schaden, +30 % Knockback | pro Treffer | unverändert | **wirkungslos auf Lv 1–3** |
| B6 | **Crushing Oath** – Unique | `data/items/crushing_oath.tres` (ComboModifier auf `sword_llh_crush`) | genau der Angriff L-L-H des Schwerts | +25 % Reichweite, +50 % Haltung | pro Treffer | trifft jetzt Guard Splitter (L-L-H, Lv 4) | **wirkungslos auf Lv 1–3** |
| B7 | **Rage** – Warrior-Klassenressource | `data/classes/warrior.tres` (`gain_per_tag`) | Tag `heavy` +4, `finisher` +6 | Ressourcengewinn pro Treffer | pro Treffer (direkt) | `heavy` greift auf Lv 1 (jeder H), `finisher` erst ab Lv 2/4 | Finisher-Bonus fehlt auf Lv 1 |
| B8 | **Item-Evolution** (z. B. Stormcaller) | `item_evolution.gd:24` | `heavy`+`finisher` | Extra-Item-XP pro Treffer | pro Treffer | unverändert | Bonus fehlt auf Lv 1–3 |

## C. Nur optisch / bereits entfernt

| Name | Fundstelle | Alt | Heute |
|---|---|---|---|
| Schadenszahlen-Farbe nach Stufe | `scripts/fx/hit_reaction_fx.gd:56` | Gelb bei Stufe 2, Orange bei Stufe 1 | Spieler-Heavies immer Heavy-Farbe (Stufe 0); nur Optik |
| Charge-Anzeige HUD/Spieler | `charge_meter.gd`, `player_view._draw_charge` | Ring und Leiste beim Halten | nie sichtbar (kein CHARGING) |
| Mastery-XP-Bonus für volle Aufladung | früher `combat_reward_tracker.gd` | +4 XP pro Treffer | mit Weapon Mastery 1.4 entfernt (nur Kill-XP) |

Gegner nutzen ihr Legacy-Charge-System nicht (KI tippt Heavy nur an). Keine Klassenfähigkeit (Q/E/R/F) prüft Aufladung; die Skills tragen höchstens `impact_sound = hit_heavy` (Ton).

## D. Nebenbefund: Light-Finisher-Abhängigkeiten (kein Charge, aber Mastery-1-Konflikt)

Seit 1.4 gibt es auf Mastery 1 **keine Finisher**. L-L-L kommt erst auf Lv 2.

| Name | Fundstelle | Effekt / Grenzen | Konflikt |
|---|---|---|---|
| Shadowrunner-Kern: „Light finishers expose Weak Points“ | `data/classes/shadowrunner.tres` (`sr_expose_on_finisher`) | Status Weak Point bei Finisher-Treffer | Klassenkern auf Lv 1 nur über E (Shadowstep) |
| Riposte Rhythm – Shadowrunner, Bladestorm | `sr_bladestorm.tres` | Finisher: −1 s Blade-Fan-Cooldown/Rang, `once_per_swing` | ab Lv 2 |
| Thousand Cuts (Talent-Capstone) – Shadowrunner | `sr_bladestorm.tres` (`sr_bs_thousand`) | Finisher: Klingenring 50 px, 50 % an andere, Bleeding, `once_per_swing` | ab Lv 2; Namensgleichheit mit dem Dolch-Pfad Thousand Cuts (H-H-H) |
| Hemorrhage – Warrior, Bloodblade | `war_bloodblade.tres` (`war_bb_hemorrhage`) | Finisher: 1 Bleeding-Stapel/Rang | ab Lv 2 |
| Blood Oath (Capstone) – Warrior, Bloodblade | `war_bloodblade.tres` (`war_bb_oath`) | Finisher gegen 3+ Bleeding: alle Stapel × 8 Schaden | ab Lv 2 |

## E. Hinweise für den geplanten Heavy-Impact-Umbau (zur gemeinsamen Prüfung)

- **Schadenswirksame Kandidaten** für „Hauptziel 100 % / weitere Treffer 50 %“: A1 Overpower, A3 Worldbreaker-Beben, B1 Aftershock, B3 Echo Blade, B4 Storm Wolf, B5 Storm Charge, B2 Finisher Power.
- **Nicht vervielfachen:** Haltung (A2, A4, A5), Rage (B7), Item-XP (B8), Markierungen (B4) und Heilung/Status (D).
- **Abweichende Formen:**
  - Die Bursts A3, B1, B3 und B4 treffen heute Gegner **in einem Radius um das getroffene Ziel und schließen das Ziel aus**. Das ist nicht „die vom Heavy getroffenen Gegner“; wie die Bursts auf das 100/50-Modell abgebildet werden, ist offen.
  - A1, A5 und B5 wirken heute **auf jeden Treffer gleich** (pro Ziel) und haben kein Hauptziel.
  - `once_per_swing` existiert bereits (HitTrigger, Echo Blade, Storm Wolf, Stone Golem pro Ziel). Eine Hauptziel-Bestimmung beim Eintritt in die Active-Phase (Maus-Zielrichtung) gibt es noch nicht; `CombatComponent` kennt nur `attack_direction`.
- **Bogen:** Heute erhält kein Bogenangriff `heavy`. Ob Precision Shots „Heavy Impact“ auslösen, ist offen.
- **Rückbau der vorläufigen Abbildung:** `HitData.is_full_power()` ist die einzige Stelle; die Spielertexte von A1, A2/A3, A4 und A5 wurden im Combat Rework auf „Heavy finishers“ umgeschrieben.
