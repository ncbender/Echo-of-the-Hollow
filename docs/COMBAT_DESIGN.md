# Combat Design – verbindlich

Dieses Dokument hält das vorgegebene Combat-Design fest. Es wird **nicht** stillschweigend an die
Implementierung angepasst. Interpretationen unklarer Punkte stehen unter „Implementierungsentscheidungen“,
Konflikte unter „Offene Designfragen“.

## Steuerung
| Eingabe | Aktion |
|---|---|
| WASD | freie Bewegung in 8 Richtungen |
| Maus | Ziel- und Angriffsrichtung |
| Linksklick | genau ein Light Attack pro physischem Klick (kein Auto-Repeat beim Halten) |
| Rechtsklick halten / loslassen | Heavy aufladen / ausführen |
| Space | Dash in WASD-Richtung; ohne WASD in Blickrichtung (zur Maus) |
| Shift | Block & Parry (seit 0.4): drücken = Parry-Fenster, halten = Block, loslassen = Ende |
| Q/E/R/F | aktive Klassenfähigkeiten (Class Foundation 0.2, `SKILL_SYSTEM.md`) |
| C | Klassen-/Talentfenster (Talente lernen überall, Rest an der Klassenstation) |
| 1 / 2 | Waffenfamilie wechseln (Prototyp) |
| F1 / F2 / F3 / F5 | Debug: Hitboxen + Lunge-/Knockback-Vektoren, Gegner spawnen, Mastery-XP, Map neu laden |

Kein Sprint.

## Bewegung
- Unmittelbar und präzise, Bewegung unabhängig von der Zielrichtung.
- Startwerte (Daten: `data/player/movement_config.tres`): 180 px/s, Light-Attack 85 %, Heavy-Charge 55 %.
- Keine träge Beschleunigung (Standard: volle Geschwindigkeit nach ~3 Frames).
- Diagonalbewegung ist nicht schneller als Achsenbewegung.

## Dash (`data/player/dash_config.tres`)
- 2 Ladungen, 300 ms Bewegung, 180 ms iFrames (ab Dash-Beginn), 2,5 s Regeneration pro Ladung,
  sequentiell (immer nur eine Ladung lädt).
- **Richtung (verbindlich seit UI/UX Polish 1.1):** mit WASD-Eingabe die normalisierte Bewegungsrichtung
  (auch wenn die Maus woanders hinzeigt, WASD hat Vorrang); ohne WASD die Blickrichtung zur Maus
  (`DashComponent.direction_for`, Totzone 0,1). Ersetzt die Regel „immer zur Maus“ aus Combat Polish 0.2.
  Ermittelt beim Dash-Start, normalisiert, während des ganzen Dashs konstant; Mausbewegung und WASD
  ändern sie nicht. Liegt der Mauszeiger näher als 4 px an der Figur (`PlayerInput.AIM_DEADZONE`),
  gilt die zuletzt gültige Blickrichtung.
- Kein Dash während eines laufenden Dashes (kein unendliches Chaining).
- Dash bricht Light Attacks und Heavy Charging ab, beendet die aktive Combo; noch nicht ausgelöste
  Treffer und Effekte verfallen.

## Light Attacks
- Ein Klick = maximal ein Angriff. Input-Buffer 120 ms.
- Combo-Fortsetzung innerhalb konfigurierbarer Fenster, neue Zielrichtung pro Angriffsschritt.
- Hitbox nur im Active-Fenster aktiv, kein Doppeltreffer pro Ziel und Schwung.

## Heavy Attacks
- Rechtsklick startet Aufladung, Loslassen löst aus.
- Stufen (Daten pro `ChargeProfile`): < 250 ms normal, 250–699 ms verstärkt, ≥ 700 ms voll.
- Keine Zusatzkosten. Während gültiger Aufladung pausiert der Combo-Timer.
- Dash-Cancel verwirft die Aufladung. Nach Release reguläre Startup/Active/Recovery-Phasen.

## Combo-System
Datengetriebener Baum. Jeder Angriff (`AttackDefinition`) besitzt: ID, Waffenfamilie, Input-Typ,
Startup/Active/Recovery, Schadensprofil (Schaden + Schadenstyp), Haltungsschaden, Bewegungsmodifikator,
Folgeangriffe (`next_light`, `next_heavy`), Cancel-Regeln (Dash-cancelbare Phasen, Chain-Verzögerung),
Freischaltbedingung, Effekt-Tags (Hooks).

Regeln:
1. Pro Combo-Zustand und Input maximal ein Folgeangriff (durch Datenmodell erzwungen: ein Feld pro Input).
2. Kein Folgeangriff → Combo beginnt neu beim Wurzelangriff des Inputs.
3. Dash beendet die Combo.
4. Zu frühe Eingaben über den Buffer.
5. Gehaltene Light-Eingabe erzeugt keine weiteren Angriffe.
6. Jeder Schritt nutzt die aktuelle Mausrichtung.
7. Waffenbeherrschung kann Knoten freischalten (`unlock_requirement`).

### Einhandschwert (`data/weapons/one_handed_sword.tres`)
| ID | Pfad | Charakter |
|---|---|---|
| `sword_light_1` | L | schneller Querhieb, mittlere Reichweite |
| `sword_light_2` | L→L | Rückhand, kleiner Vorwärtsschritt, etwas schneller |
| `sword_light_3` | L→L→L | weiter Rundumhieb (160°), längere Recovery, mehr Haltungsschaden |
| `sword_light_4_mastery` | L→L→L→L | nur mit `mastery.one_handed_sword.1` (Debug F3) |
| `sword_heavy` | H | Grund-Heavy mit Charge-Stufen |
| `sword_lh_thrust` | L→H | langer, schmaler Stich mit großem Vorwärtsstoß |
| `sword_llh_crush` | L→L→H | langsamer 180°-Schlag, sehr hoher Haltungsschaden und Knockback |

### Zweihandschwert (`data/weapons/two_handed_sword.tres`) – Phase E
Langsamer (Light ~0,58 s statt 0,38 s), Reichweite 44–58 px statt 30–42 px, Charge-Multiplikatoren bis
×2,3 Schaden / ×3 Haltung, Charge-Bewegung 45 %, Light-Bewegung 70 %.

| ID | Pfad | Charakter |
|---|---|---|
| `greatsword_light_1` | L | schwerer Querschwung |
| `greatsword_light_2` | L→L | Rückschwung |
| `greatsword_light_3` | L→L→L | 180°-Ernte-Bogen, Finisher |
| `greatsword_heavy` | H | Grund-Heavy |
| `greatsword_lh_overhead` | L→H | schmaler, weiter Überkopfschlag |
| `greatsword_llh_whirl` | L→L→H | 180°-Wirbel mit großem Vorstoß |

### Gegner „Grunt“ (`data/enemies/`) – Phase F
Verfolgt den Spieler, greift in Reichweite mit `grunt_swipe` an (0,45 s Startup = Telegraph,
12 Schaden), 0,9 s Cooldown. Haltungsbruch unterbricht Telegraph/Angriff (Treffer verfällt),
Tod → 0,8 s Ausblenden, danach entfernt. Debug-Spawn mit F2.

## Animation-Cancelling
- Light Attacks: in allen Phasen per Dash abbrechbar.
- Heavy Charging: jederzeit per Dash abbrechbar.
- Heavy Attacks: Dash-Cancel nur in den pro Angriff erlaubten Phasen (Schwert: Startup + Recovery).
- Bereits verursachter Schaden bleibt; noch nicht ausgeführte Treffer verfallen; keine Effekte nach
  dem Cancel; ein Angriff kann durch Cancels nie mehrfach ausgelöst werden.
- Folgeangriffe brechen die Recovery des vorherigen Angriffs ab (Chain-Cancel), frühestens nach
  `chain_delay`.

## Treffer und Feedback
Hitbox (Kreissektor) / Hurtbox, Schaden, Lebenspunkte, Haltung (Poise), Trefferblitz, Schadenszahlen,
optionaler Knockback, kurzer Hitstop bei schweren Treffern, Kamera-Shake, Debug-Anzeige der Trefferbereiche.

## Implementierungsentscheidungen (Interpretation, kein Designwechsel)
- **Input-Buffer ist einslotig:** die zuletzt gepufferte Angriffseingabe gewinnt. Dash hat einen eigenen
  Buffer gleicher Länge. Ein Dash-Cancel leert den Angriffs-Buffer.
- **Gehaltener Rechtsklick:** Wird RMB während eines nicht unterbrechbaren Zustands gedrückt und über das
  120-ms-Fenster hinaus gehalten, beginnt die Aufladung, sobald der Charakter frei ist. Nach einem
  Dash-Cancel muss RMB erneut gedrückt werden (Aufladung geht verloren).
- **Combo-Fenster** beginnt nach Ende der Recovery (`combo_window` pro Angriff). Während der Recovery
  kann ab `chain_delay` direkt verkettet werden.
- **Volle Aufladung** wird beliebig lange gehalten, es gibt keinen automatischen Release.
- **Treffer während iFrames** werden nicht registriert; derselbe Schwung kann nach Ende der iFrames
  noch treffen, falls sein Active-Fenster dann noch läuft.
- **Waffenwechsel** nur im Leerlauf, setzt die Combo zurück.
- **Hitstop** ist eine Feel-Schicht, begrenzt auf 0,15 s pro Treffer (seit Overnight 2 lokal, s. u.).
- **Spieler-Leben (Phase F):** 100 HP, bei 0 HP nach 1,5 s Respawn am Startpunkt (Prototyp-Lösung).
- **Knockback** siehe Abschnitt „Knockback & Attack Lunge (Combat Polish 0.2)“.

## Offene Designfragen
- **Heavy-Startup des Zweihänders** ist per Dash abbrechbar (wie beim Schwert). Falls Zweihand-Heavies
  stärker „committen“ sollen, nur `dash_cancel_phases` in den Daten ändern.
- ~~Spieler und Gegner überlappen~~ → seit Overnight 2 behoben (siehe unten).
- **Dash durch Gegner?** Aktuell blockieren Gegner auch den Dash (man gleitet an ihnen ab). Ob der Dash
  Gegner durchqueren soll, ist eine Feel-Entscheidung für den Playtest.
- Mehrere Klicks innerhalb eines einzelnen Physik-Frames (16 ms) zählen als eine Eingabe. Bei 60 Hz
  praktisch irrelevant; falls nötig, Physik-Tickrate erhöhen.
- ~~Player-Treffer-Reaktion~~ → seit Overnight 2 definiert (siehe unten).

## Änderungen Overnight 2 (technisch, Timings unverändert)
Keine Angriffs-, Bewegungs-, Dash- oder Combo-Werte wurden verändert. Geändert/ergänzt:

1. **Kollision Spieler ↔ Gegner:** Spielerkörper kollidiert jetzt mit Gegnern (Maske Welt + Gegner).
   `BodyContact.strip_push` entfernt pro Tick die Geschwindigkeitskomponente, die in einen anderen
   Charakter drücken würde → niemand schiebt niemanden (auch nicht über Godots Penetrations-Recovery),
   Knockback läuft über `move_and_slide` (keine Sprünge, Wände halten). Gegner untereinander ebenso.
2. **Lokaler Hitstop:** statt `Engine.time_scale` frieren nur Angreifer und Ziel ein
   (`apply_hitstop`, Maximum statt Summe, Obergrenze 0,15 s). Eingaben während des Freezes werden
   weiter gepuffert (ohne zu altern). Gleiche Dauer wie vorher; UI, andere Gegner, Timer laufen weiter.
3. **Trefferreaktionen des Spielers** (Angriffsattribut `hit_reaction`, Werte = **Testwerte**,
   `data/player/hit_reaction_config.tres`):

| Typ | Wirkung | Standarddauer |
|---|---|---|
| NONE | nur Schaden | – |
| FLINCH | Schaden + Feedback, keine Unterbrechung | 0,12 s |
| INTERRUPT | bricht unterbrechbare Aktion ab, danach keine Angriffe (Bewegen erlaubt) | 0,25 s |
| KNOCKBACK | wie INTERRUPT + ×1,8 Knockback, keine Bewegung/Dash, beendet laufenden Dash | 0,35 s |
| STUN | keine Bewegung, Angriffe, Dash | 0,6 s |

   - Dash-iFrames verhindern Treffer und damit jede Reaktion.
   - `uninterruptible_phases` am Angriff (Hyper Armor) reduziert Unterbrechungen zu FLINCH.
   - `resistance` (Konfig) bzw. `bonus_resistance` (Laufzeit) für spätere Fähigkeiten: Reaktionen bis zu
     dieser Stufe werden zu FLINCH.
   - Eine schwächere Reaktion ersetzt nie eine laufende stärkere.
4. **Grunt:** Wischer = FLINCH; jeder 3. Angriff ist ein **Slam** (0,7 s roter Telegraph, KNOCKBACK).
   Neuer Gegnerinhalt, damit Reaktionen testbar sind; Spieler-Combat unverändert.
5. **Neuer gesperrter Knoten** `greatsword_light_4_mastery` (nur über Waffenbeherrschung erreichbar).

## Knockback & Attack Lunge (Combat Polish 0.2)
**Knockback ist eine Distanz in Pixeln** (vorher eine geschwindigkeitsartige Stärke × `knockback_scale`).
Es gibt genau ein Modell für Spieler und Gegner: `KnockbackMotion` (`scripts/combat/knockback_motion.gd`).

- `AttackDefinition.knockback` = Rückstoßdistanz gegen ein Standardziel. `HitData.knockback` =
  Angriffsrichtung × Distanz (`AttackModifier` können es ändern).
- Der Empfänger skaliert **einmal**: Gegner × `(1 − knockback_resistance)`, Spieler × Reaktions-
  Multiplikator (nur bei KNOCKBACK-Reaktion, 1,8). Aufladestufen multiplizieren Knockback nicht.
- Die Distanz wird mit konstanter Verzögerung zurückgelegt (`knockback_decay` = Tempo, nicht Weite),
  über `move_and_slide`: Wände und andere Charaktere stoppen sie, der Rest verfällt (nichts wird
  gespeichert, keine Sprünge, kein Teleport). Mehrere Treffer addieren ihre Distanzen.
- Gegner pausieren eigene Schritte/Lunges, solange sie zurückgestoßen werden → die Distanz ist exakt.
- Haltung/Hitstun sind unabhängig: Resistenz verringert nur die Position, nie den Haltungsschaden.

| Waffe (Testwerte, px) | L1 | L2 | L3 | L4 (Mastery) | Heavy | L-H | L-L-H (Finisher) |
|---|---|---|---|---|---|---|---|
| Einhandschwert | 6 | 6 | 10 | 22 | 18 | 14 | 30 |
| Zweihandschwert | 12 | 12 | 18 | 30 | 35 | 28 | 45 |
| Grunt (gegen Spieler) | Wischer 3,5 | | | | Slam 13 (×1,8 = 23,4) | | |

Grunt-Werte sind umgerechnet, sodass der Rückstoß auf den Spieler gleich bleibt (vorher ~3 / ~23 px).
Echo-Schockwelle: 5 px (`knockback_distance`). Andere Waffenfamilien existieren noch nicht.

**Gegnerresistenz** (`EnemyConfig.knockback_resistance`, −1…1, rein datengetrieben):

| Klasse | Wert | Wirkung | Beispiel |
|---|---|---|---|
| klein | −0,5 | ×1,5 | – |
| Standard | 0 | ×1 | Grunt |
| schwer | 0,5 | ×0,5 | – |
| Elite | 0,8 | ×0,2 | – |
| Boss | 1 | kein Positions-Knockback (Haltung wirkt voll) | Grove Warden (`grove_warden_config.tres`) |

**Attack Lunge** (`AttackDefinition.lunge_distance`, existierte bereits): Vorwärtsbewegung entlang der
beim Angriffsstart festgelegten Richtung, gleichmäßig über Startup + Active, zusätzlich zur
(verlangsamten) Laufbewegung. Endet mit dem Angriff (Dash-Cancel, Unterbrechung, Recovery); Wände und
Körper blockieren ihn. Seit 0.2 ist die Gesamtstrecke exakt `lunge_distance` (vorher bis zu einen Tick
mehr). Werte **unverändert** aus dem bestätigten Playtest-Stand:

| Waffe (px) | L1 | L2 | L3 | L4 | Heavy | L-H | L-L-H |
|---|---|---|---|---|---|---|---|
| Einhandschwert | 6 | 12 | 14 | 22 | 8 | 36 (Stoß) | 10 |
| Zweihandschwert | 8 | 12 | 16 | 20 | 10 | 20 | 24 |

**Zusammenspiel:** Light-Knockback ≤ Lunge des Folgeangriffs + Reichweitenpuffer, deshalb trifft
L-L-L im Stand (ohne WASD) einen Standardgegner vollständig (getestet für beide Waffen). Finisher
(L3/L-L-H/Heavy) dürfen weiter schieben, sie beenden die Combo. Keine Zielverfolgung, kein
Heranziehen: die Richtung bestimmt allein die Maus.

**Debug (F1):** grüner Pfeil = Lunge des laufenden Angriffs, roter Pfeil = verbleibender Knockback
(Spieler und Gegner, 1:1 in px). Overlay-Zeilen „Lunge“ (Distanz, Richtung, MOVING/done) und
„Knockbk“ (zuletzt getroffener Gegner: angewendete Distanz, Resistenz, tatsächlich zurückgelegt, Vektor).

## Vorschläge für den Feel-Test (NICHT umgesetzt)
- ~~Light-Treffer zu weich (~3 px)~~ → Combat Polish 0.2: 6 px (Schwert) / 12 px (Zweihänder).
- Dash zur Maus: Nach dem Dash läuft die Figur mit voller Geschwindigkeit in Dash-Richtung weiter und
  dreht dann zur WASD-Richtung (bestehendes Verhalten). Prüfen, ob das bei Dash ≠ WASD gut wirkt.
- Reaktionsdauern (v. a. STUN 0,6 s) im Kampf gegen mehrere Grunts prüfen.
- Dash durch Gegner erlauben? (siehe offene Designfragen)
- Hitstop-Gefühl jetzt lokal: prüfen, ob schwere Treffer weiterhin „Gewicht“ haben.

## Class Foundation 0.2 (Erweiterungen, bestehende Werte unverändert)
Unverändert geblieben sind:
- alle Angriffs-, Dash-, Bewegungs-, Combo-, Knockback- und Lunge-Werte
- die Gegner-KI

Neu (Details in `SKILL_SYSTEM.md`):
- **Angriffsgeschwindigkeit wirkt:** `attack_speed = clamp(1 + Attack Speed % / 100, 0,75, 1,4)`.
  - Beschleunigt Startup, Active, Recovery und `chain_delay`; die Lunge-Distanz bleibt exakt.
  - Nicht beschleunigt: Heavy-Charge-Stufen, Combo-Fenster, Input-Buffer, Dash.
  - Ohne Attack-Speed-Quellen ist sie 1,0, das alte Timing bleibt also exakt.
  - Neue Quellen: Talente, Buffs, Shadowrunner-Grundwert +5 %. Bestehende Quellen sind die
    Storm-Ore-Prägung (+3 %) und der Swift-Affix; sie verändern jetzt tatsächlich die Timings.
- **Skills (Q/E/R/F):**
  - Starten nur dort, wo ein Dash-Cancel erlaubt wäre, und brechen Light-Angriffe ab.
  - Cast-Lock je Skill, den ein Dash beendet.
  - Skill-Bewegungen (Blade Rush, Shadow Strike, Shadowstep) sind **kein Dash**: eigene Distanz,
    keine Ladung, keine iFrames, Wände stoppen sie. Der Dash bleibt auf Space, zur Maus, mit
    2 Ladungen.
- **Status:**
  - Bleeding (Schaden über Zeit) und Chill (nur Fortbewegung des Gegners, Boss-Grenze).
  - Marken: Arcane Mark, Weak Point, Death Mark; Smoked (Verlangsamung).
- **Trefferquellen:** direkt, Skill, ausgelöst, Status. Ausgelöste Ketten enden nach Tiefe 1.

### Vorschläge für den Feel-Test (Class Foundation 0.2, NICHT umgesetzt)
- **Cast-Locks:** 0,12–0,4 s (Whirlwind 1,2 s). Prüfen, ob sich Skills zwischen Combos flüssig anfühlen.
- **Trials:** Drei Grunts sterben im Fenster-Playtest in 2–4 s, da sie eng stehen und die Trial
  auf Level 12 läuft. Für einen echten Lerneffekt eventuell mehr oder zähere Gegner.
- **Arcane Bolt:** 0,45 s Cooldown und 8 Mana bei 8 Mana/s Regeneration. Prüfen, ob die
  Rotation ohne Nahkampf trägt.
- ~~Shadowstep als freier 80-px-Schritt~~ → Class Combat Polish 0.3: zielgebundener Gap-Closer (Playtest-Feedback:
  freie Skill-Dashes neben den zwei Universal-Dashes störten). Blade Rush ebenso; Shadow Strike/Piercing Lunge
  sind kurze Angriffs-Lunges (≤ 40 px). Prüfen: Reichweiten 130/110 px und Kegel 70°/50° im Gefecht.

## Block & Parry (Combat Defense & Feedback 0.4)
Drei taktische Antworten auf einen Angriff:
- **Dash:** Ausweichen mit iFrames (unverändert).
- **Block:** verlässlich, aber nur teilweise Schutz.
- **Parry:** kurzes Fenster mit Belohnung.

Alles ist datengetrieben (`DefenseProfile`, `data/combat/defense/`) und läuft im `DefenseComponent`
am Player.

**Ablauf auf Shift:**
- **Drücken** öffnet das Parry-Fenster.
- Weiter **halten** wird danach zum Block, sofern das Profil blocken kann.
- **Loslassen** löst eine Recovery aus. Nach einem Parry-Fenster ohne Treffer ist das der Whiff,
  nach einem Block die Block-Recovery.
- Halten öffnet nie ein neues Parry-Fenster. Ein neuer Parry braucht einen neuen Druck und den
  Anti-Spam-Cooldown (gerechnet ab dem letzten Druck).
- **Start** nur dort, wo ein Dash-Cancel erlaubt wäre: Light-Angriffe immer, Heavy-Aufladung immer,
  Heavy-Angriffe nur in ihren Dash-Cancel-Phasen. Also kein neuer Angriffscancel, und Combo-Timings
  bleiben unverändert (getestet).
- **Während Verteidigung:** keine Angriffe und Skills, Bewegung verlangsamt.
- **Beenden:** Dash, unterbrechende Trefferreaktion (INTERRUPT+) und Tod beenden die Verteidigung
  sofort. Die Dash-iFrames bleiben unverändert und werden nie mit Block/Parry gestapelt.
- **Treffer** werden vor dem Schaden aufgelöst (`Hurtbox.hit_filter`). Ein Treffer, der schon gelandet
  ist, kann nicht nachträglich pariert werden.

| Profil | Waffe | Parry-Fenster | Parry-Bogen | Anti-Spam | Whiff-Recovery | Block | Block-Bogen | Bewegung | Block-Recovery | Parry-Haltung | Counter |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Sword Guard | Einhandschwert | 150 ms | 120° | 550 ms | 300 ms | −45 %, Knockback ×0,5 | 120° | ×0,5 | 150 ms | 30 | 1 s, ×1,5 |
| Heavy Guard | Zweihandschwert | 130 ms | 110° | 650 ms | 400 ms | −25 %, Knockback ×0,6 | 100° | ×0,4 | 250 ms | 45 | 1 s, ×1,6 |
| Shield Guard | Oak Shield (Nebenhand, überschreibt die Waffe) | 120 ms | 140° | 600 ms | 300 ms | −65 %, Knockback ×0,35 | 160° | ×0,6 | 100 ms | 20 | 0,8 s, ×1,3 |

**Parry:**
- Der Treffer macht keinen Schaden, keinen Knockback und löst keine Reaktion aus.
- Der Angreifer erhält Haltungsschaden (× `EnemyConfig.parry_poise_multiplier`).
- Normale Gegner werden unterbrochen und 0,5 s „benommen“ (`parry_interrupts`, `parry_daze`).
- Counter-Fenster: Der nächste eigene Waffentreffer macht mehr Schaden (Tag `counter`, HUD „COUNTER!“).
- Die Verteidigung endet sofort, man kann direkt kontern.

**Block:**
- Schaden und Knockback werden reduziert, die Reaktion höchstens FLINCH.
- Der Angreifer erhält 4–6 Haltung.
- Gegen **Guard Breaking** scheitert der Block: voller Treffer, Reaktion, Recovery und
  „GUARD BREAK“-Anzeige.

**Richtung:** Nur Angriffe aus dem Frontbogen um die Blickrichtung (Maus) zählen; von hinten wirkt
nichts.

**Angriffs-Regeln** (`AttackDefinition.defense_flags`: Blockable, Parryable, Guard Breaking):
| Angriff | Blockbar | Parierbar | Guard Breaking |
|---|---|---|---|
| Grunt Swipe | ja | ja | – |
| Grunt Slam | ja | ja | **ja** (Block bricht, Parry oder Dash nötig) |
| Grove Warden Swipe (`grove_warden_attacks.tres`) | ja | **nein** | – |
| Grove Warden Crushing Slam | **nein** | **nein** (UNBLOCKABLE) | – |

**Unblockable-Telegraph:** eigene Farbe (Magenta), Zickzack-Kontur statt glatter Kante und „!!“ über
dem Gegner, also nicht nur farbcodiert; dazu ein eigener Warnton.

**Bosse:**
- Grove Warden: `parry_interrupts = false` und 0,3× Parry-Haltung. Parries unterbrechen ihn nie.
- Ein Haltungsbruch ist möglich, ein Dauer-Lock nicht.
- Die Werte und Timings seiner Angriffe sind identisch zu vorher; nur die Verteidigungs-Flags sind neu.

**Keine Stamina:** Block wird über begrenzte Reduktion, Verlangsamung, Recovery, Guard Break und
Unblockables balanciert (kein Ressourcen-Umbau).

### Vorschläge für den Feel-Test (0.4, NICHT umgesetzt)
- Parry-Fenster 120–150 ms gegen den Grunt-Swipe-Telegraph (450 ms): zu leicht oder zu schwer?
- Ist Sword-Block (−45 %) neben Dash attraktiv genug, und ist Heavy Guard (−25 %) zu schwach?
- Sollte der Grunt-Slam parierbar bleiben (aktuell ja) oder nur ausweichbar sein?
