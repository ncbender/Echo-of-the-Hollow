# Weapon Base Damage 1.2 – Special Weapons V2

Branch `dev/weapon-base-damage-12` (Basis `a969493`, = 1.1). Erweitert `WEAPON_BASE_DAMAGE_1_1.md`.

## 1. Baseline (Phase A)
| Item | Familie | Level-Quelle | globale Basisboni | Quality | Sondermechanik |
|---|---|---|---|---|---|
| stormcaller_fang | one_handed_sword | Profil 15 | physical +8, poise +4 | ja (Profil) | Evolution: Stufe 2 +6 physical, +10 finisher_power; Mutationen Storm Charge / Steadfast; 2 Essenzen |
| crushing_oath | one_handed_sword | Profil 15 | physical +4 | ja (Profil) | `ComboModifierEffect` auf `sword_llh_crush`: Reichweite ×1,25, Haltung ×1,5, Schaden ×1,0; 1 Sockel |
| echo_blade | one_handed_sword | **keine** (Instanz 1) | physical +8 | **nein** (kein Profil) | `EchoShockwaveEffect`: Heavy Finisher, Radius 52, 40 % des Treffers, Haltung 10, 0,5 s Cooldown, einmal pro Schwung, trifft Hurtboxen direkt (keine Rekursion, keine Effekte/XP) |

Bis 1.1 liefen alle drei über die Kompatibilitätsgrenze (Familienreferenz 12, Quality auf den globalen Boni).

## 2. Umsetzung
- **Daten** (nur die drei Items): `base_weapon_damage = 14.016`; echo_blade zusätzlich `base_item_level = 15` (freigegebene
  Prototyp-Stufe, da kein Profil). model_factor = 14,016 / B_ref(15) = 1,0. Erzeugung über den bestehenden `ItemCreation`-Vertrag;
  kein neuer Code.
- **V2:** globale Boni (physical +8 / +4 / +8, Stormcaller poise +4) bleiben unverändert in `base_stats` und wirken genau einmal
  über `CharacterStatModifier`. Quality skaliert sie nicht mehr (bestehende Regel `ItemStats.quality_scales_base_stats` für
  Modellwaffen), nur noch `base_weapon_damage`. Evolution, Mutationen, Sockel, Essenzen, Unique-Effekte: unverändert.
- Keine Änderungen an Combat-Code, Attack-Multiplikatoren, anderen Items, Pools, Skills.

## 3. Schaden vorher → nachher (neue Instanzen, ilvl 15, Quick / Heavy, ohne andere Stats)
| Waffe | Q0 vorher | Q0 nachher | Q20 vorher | Q20 nachher |
|---|---|---|---|---|
| stormcaller_fang | 12,96 / 28,08 | **15,14 / 32,80** | 13,06 / 28,29 | **16,65 / 36,08** |
| crushing_oath | 12,48 / 27,04 | **14,58 / 31,58** | 12,53 / 27,14 | **16,03 / 34,74** |
| echo_blade | 12,96 / 28,08 | **15,14 / 32,80** | – (kein Quality) | – |
Waffentreffer +16,8 % durch die Referenzbasis bei ilvl 15 (14,016 / 12), globale Boni wie zuvor. Echo-Schockwelle steigt
indirekt mit dem Treffer (40 % des tatsächlichen Treffers, bisherige Berechnung).

**Globale Boni vorher → nachher:** Werte unverändert; nur der Quality-Anteil entfällt (z. B. Stormcaller Q20: physical 8,8 → 8,
poise 4,4 → 4; Oath Q20: 4,4 → 4). Physische Skills verlieren mit Stormcaller/Oath nur diesen Quality-Anteil (max. −0,7 %);
bei Q0 und mit Echo Blade unverändert. Keine Kompensation.

## 4. Save v13
- `SaveSystem.VERSION` 12 → **13**. Technisch nötig: v12-Stände (Build 1.1) können die drei Waffen bereits ohne `base_damage`
  enthalten; eine Erweiterung des v11→v12-Schritts würde sie nie erreichen.
- `_v12_to_v13` nutzt dieselbe Funktion wie v12 (`_assign_weapon_bases`, jetzt gemeinsam) mit der eingefrorenen Tabelle
  `V13_WEAPON_MODELS` (B1 12, Basis 14,016, Erzeugungslevel 15): Basis = B_ref(**gespeichertes** ilvl) × 1,0.
  Vorhandene Werte werden nie ersetzt; Evolution, Essenzen, Sockel, Quality, Affixe bleiben.
- **Folge für alte Echo Blades:** Sie wurden ohne Level-Quelle erzeugt und sind mit Level 1 gespeichert (das Format lässt `ilvl`
  bei 1 weg). In 1.2 blieb dieses Level → Basis 12,0; **seit 1.2.1** werden sie im selben Schritt zu Level 15 / 14,016
  (Abschnitt 7). Stormcaller und Oath waren immer mit ilvl 15 gespeichert → 14,016.

## 5. Tests
`test_weapon_base_damage` (29 Tests; neu/ersetzt für 1.2: V2-Boni ohne Quality, Stormcaller Stufe 2 genau einmal, Quick/Heavy
aller drei am echten Spieler bei Q0/Q20, Echo-Schockwelle am echten Treffer (40 %, nur Umstehender im Radius, nicht das Ziel,
nichts außerhalb, Haltung 10), Persistenz Equip/Lager/Save-Load, v12→v13-Migration inkl. Level-1-Echo-Blade, Erzeugung mit
explizitem Level 30). Wiederverwendet: `item_effects` (Oath-Reichweite/Haltung, Echo einmal pro Schwung, Rekursionsschutz),
`evolution`, `essences`.
Angepasst: `test_item_foundation` (Oath-Quality wirkt nicht mehr auf den globalen Bonus).
Mutationsprobe (v13-Schritt abgeschaltet) → 2 Migrationstests rot.

Lauf: weapon_base_damage, item_foundation, item_effects, evolution, essences, sockets_quality, crafting_stats, crafting_ops,
crafting_save, forge_ui, save, save_foundation, stash, equipment, inventory_ui, affix_pool, combat_data, weapon_families, hits,
defense, skills – **194 bestanden, 0 fehlgeschlagen**. `check_project.ps1`: OK. `crafting_loop` (bekannter Altfehler) nicht ausgeführt.

## 6. Offen
1. ~~Alte Echo Blades auf Level 1~~ → entschieden und umgesetzt in 1.2.1 (Abschnitt 7).
2. Echo Blade hat weiterhin keine Quality (kein CraftingProfile); ein Profil hinzuzufügen wäre eine neue Crafting-Fähigkeit.
3. Die Kompatibilitätsgrenze (Waffe ohne Basis → Familienreferenz) wird von keinem Daten-Item mehr genutzt, nur noch vom
   unbewaffneten Fallback. Entfernen erst nach Entscheidung zum Fallback.

## 7. 1.2.1 – Echo-Blade-Migration (Branch `dev/echo-blade-migration-fix`)
- **Bedingung** (alle drei, am Originaleintrag): `def` exakt `"echo_blade"`, gespeichertes Level exakt 1 (`ilvl` fehlt – das
  Format lässt 1 weg – oder ist 1), kein `base_damage`. Dann `ilvl = 15`, `base_damage = 14,016`; Affixe, Quality, Evolution,
  Essenzen, Sockel, Fav/Lock, Herkunft, Fortschritt bleiben. Bag, Lager, verwaiste Items.
- **Reihenfolge:** `base_damage` wird für echo_blade erst im Schritt v12→v13 ergänzt (v11→v12 kennt die Waffe nicht, das Laden
  ergänzt nie). `_restore_legacy_echo_blades` läuft in `_v12_to_v13` **vor** `_assign_weapon_bases`, sonst würde die
  allgemeine Übernahme die Klinge vorher zu Level 1 / 12,0 machen. Ältere Stände (v2–v11) laufen durch dieselbe Kette
  (v2→v3 schreibt `ilvl: 1` explizit – zählt als Level 1).
- **Save-Version:** unverändert 13. Ein v13→v14-Schritt wäre wirkungslos: in v13 trägt jede Echo Blade bereits `base_damage`.
- **Ausnahmen (bestätigt):** Echo Blades mit vorhandenem `base_damage` (auch 12), mit Level ≠ 1, andere Waffen/Items und neue
  Instanzen bleiben unberührt. **Nicht korrigierbar:** Stände, die bereits mit dem 1.2-Build als v13 gespeichert wurden – ihre
  Basis 12 ist nicht mehr von einer bewusst gesetzten zu unterscheiden; keine Heuristik, sie bleiben unverändert.
- Kein Sondercode in `WeaponDamage`, `ItemStats` oder `ItemCreation`.
- **Tests:** `test_weapon_base_damage` neu: Fälle A–E in einem Payload (inkl. Lager/Waisen, explizites `ilvl: 1`, Level 30,
  Stormcaller Level 1), F (v12-Datei unter `user://test_saves/` laden → speichern → erneut laden; Schritt zweimal = keine
  Änderung), G (v2, v3, v10, v11, v12 → gleiches Ergebnis; v13 unverändert); `test_migration_v12_to_v13` angepasst.
  Lauf weapon_base_damage, save, save_foundation, item_foundation, stash: **76 bestanden, 0 fehlgeschlagen**.
  Mutationsprobe (Korrektur abgeschaltet) → 4 Tests rot.
