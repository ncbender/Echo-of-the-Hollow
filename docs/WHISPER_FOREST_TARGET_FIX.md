# Whisper Forest – Placed Enemy Target Fix 1.0

Branch `fix/whisper-forest-enemy-targets` von `dev/roots-remember-m3` @ `2ff3a6b`. Eine Szenenänderung, keine Code-, Daten-
oder Balanceänderung, keine Save-Version (bleibt **v15**). Fremde Änderungen (`project.godot`, `docs/Design/`, `docs/tasks/`)
unberührt.

## 1. Bestätigte Ursache

`Enemy._ready` (`scripts/enemies/enemy.gd`) sucht sein Ziel **einmal**: `target = get_tree().get_first_node_in_group(&"player")`.
Der Spieler tritt der Gruppe erst in `Player._ready` bei. Godot ruft `_ready` in der in der Szenendatei gespeicherten
Geschwisterreihenfolge auf. Im Whisper Forest stand `Enemies` vor `Player`.

Isolierte Diagnose mit synthetischem Charakter (temporärer Test, nicht versioniert):

| Prüfung | Ergebnis |
|---|---|
| target nach dem Laden | Grunt und Grove Warden `null`; Spieler danach in der Gruppe (`player_in_group = true`) |
| dauerhaft null? | ja: nach 300 Frames, Spieler 60 px neben dem Grunt (Aggro 260) weiterhin `null`, Grunt 0 px bewegt, Kampf IDLE |
| Ziel außerhalb der Reichweite? | nein (Spieler innerhalb der Aggro-Reichweite) |
| KI inaktiv trotz Ziel? | nein: Ziel manuell gesetzt → Grunt läuft 55 px, greift an, Spieler 110 → 88 HP |
| Reihenfolge (Ready-Signale) | Warden's Rest (Player vor Enemies): `player ready` (Gruppe 1) → `enemy ready` → Ziel gesetzt. Whisper Forest: `enemy ready` (Gruppe **0**) → `player ready` → Ziel `null` |

Damit ist die Initialisierungsreihenfolge die Ursache: die einzige Zielsuche läuft, bevor der Spieler registriert ist, und wird
nie wiederholt. Hinweis: Ein Umsortieren **zur Laufzeit** (`move_child` vor `add_child`) änderte die Ready-Reihenfolge im Test
nicht; maßgeblich ist die gespeicherte Reihenfolge der Szenendatei. Der Fix wurde deshalb an der echten Szene nachgewiesen
(Abschnitt 4: dieselben Tests gegen die unveränderte Szene → rot).

Encounter-Gegner sind nicht betroffen (`GameMap.spawn_enemy` setzt `enemy.target = player`). Andere Karten mit platzierten
Gegnern: nur Warden's Rest (bereits Player vor Enemies).

## 2. Minimaländerung

`scenes/maps/whisper_forest.tscn`: der Knoten `Player` steht jetzt direkt **vor** `Enemies` (nur verschoben, Werte identisch;
Darstellung über Y-Sortierung unverändert; `DebugOverlay`-Pfad `../Player` unverändert). Gewählt, weil der Auftrag einen lokalen
Fix bevorzugt und er genügt. Keine Änderung an `Enemy`, `Player`, `GameMap` oder Daten.

Verworfene Alternative (gemeinsame Korrektur): erneute Zielsuche in `Enemy._to_target`, solange `target == null`. Robuster für
künftige Karten, berührt aber alle Gegner – nicht nötig, solange nur diese Karte betroffen ist.

## 3. Betroffene Gegner und unveränderte Kampfregeln

Betroffen: Whisper Forest `GruntA/B/C`, `GroveWarden`. Sie greifen jetzt regulär an – bisher taten sie es nie.

Unverändert: HP, Schaden, Tempo, Windup, Poise, Aggro-/Angriffsreichweiten (Grunt/Warden 260 / 28), Boss-Rank und -Skalierung,
Angriffsfamilien, feste Drops, Equipment-Tabelle der Grunts, `persistent_id`/Defeat-Flag, Warden's Cache, garantierter
Rare-Reward, Claim-/Save-Verhalten. Es gibt weiterhin **kein Leash** (bestehend): ein Gegner verfolgt nur, solange der Spieler in
seiner Aggro-Reichweite ist, und bleibt sonst stehen; ein gültiges Ziel löst keinen Angriff aus der Ferne aus.

Abstände (M1): Haven-Eingang → nächster Gegner > 260 px (alle bleiben ruhig). Östlicher Ausgang: Annäherungspunkt (290, −156)
278 px und Rückkehr-Spawn (262, −164) 286 px vom Warden – außerhalb seiner 260 px. Die Grunts (v. a. GruntC bei (230, −100))
reichen dagegen bis an den Ostausgang und greifen dort jetzt regulär an.

## 4. Tests und Ergebnisse

`tests/integration/test_whisper_forest_target_fix.gd` (8): Ziel für Grunts und Warden (+ Reihenfolge), kein Zielzugriff ohne
Spieler bzw. mit freigegebenem Ziel, außerhalb der Reichweite kein Kampf, innerhalb echte Angriffe mit Schaden (Grunt und Warden),
Ostausgang: Warden ruhig bei Annäherung und Rückkehr + Übergang funktioniert, Kartenwechsel und Save/Load (inkl. echtem
Angriff), Warden-/Cache-/Grunt-Werte unverändert + besiegter Warden kehrt nicht zurück, Encounter-Gegner und Rootbound Sentinel.

- Neue Suite: **8/8** grün. Gegen die unveränderte Szene: **4/8 rot** (Ziel, echter Angriff, Save/Load, Grunt-Ziele) → Fix wieder
  eingesetzt.
- Mit `enemy, world, world_ui, grove_warden_reward, roots_remember_m1, roots_remember_m3, hollowwood, hollowwood_loot, economy,
  knockback, class_trials_m31, workshops, loop` (alle Suites, die die Whisper-Forest-Szene laden): **116/116** grün.
- `check_project.ps1`: OK. Nicht gelaufen (Efficient Testing 1.1): Full-Suite, Prolog-/Haven-Playtests, Class-Trial-Läufe,
  Arena/Crafting/Galerie. `test_migration_v3_to_v4` unberührt.

## 5. Echte Funktionsprüfung

`tests/playtest/forest_target_visual_check.gd` im echten Fenster (1600×900), 6/6 OK, Screenshots (`tests/output/forest_targets/`)
angesehen. Gemessen im laufenden Spiel:

| Situation | Ergebnis |
|---|---|
| Haven-Eingang, 2 s | größte Gegnerbewegung 0,00 px, Spieler 110/110 |
| Grunt, Spieler 120 px entfernt | Grunt läuft 107 px heran, greift an, Spieler 110 → 88 |
| Grove Warden, Spieler nah | Angriff gestartet, Spieler 110 → 99 |
| Östlicher Ausgang (278 px vom Warden) | Warden 0,00 px bewegt, IDLE; Übergang in die Tangled Wood funktioniert |

Der Angriff wurde also tatsächlich ausgeführt und hat Schaden verursacht, nicht nur ein Ziel erhalten. Keine vollständige
Boss-Playteststrecke.

## 6. Restrisiken

- **Spielgefühl ändert sich:** Der Whisper Forest war bisher faktisch gefahrlos (Gegner passiv). Jetzt greifen drei Grunts und der
  Grove Warden an – auch beim Sammeln in ihrer Nähe und am Ostausgang (Grunts). Das ist das vorgesehene Verhalten, aber für
  Spieler neu; Balance wurde nicht geändert.
- **Kein Leash:** Ein verfolgender Gegner bleibt dort stehen, wo der Spieler seine Reichweite verlässt (bestehendes Verhalten,
  unverändert).
- **Reihenfolge als Konvention:** Künftige Karten mit platzierten Gegnern brauchen `Player` vor `Enemies` (bzw. später die
  verworfene gemeinsame Korrektur). Die Tests von Whisper Forest und Warden's Rest prüfen das.
