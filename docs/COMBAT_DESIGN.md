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
| Space | Dash |
| Shift | später: defensiver Aktionsslot (gebunden, ohne Funktion) |
| Q/E/R/F | später: Klassenfähigkeiten (gebunden, ohne Funktion) |
| 1 / 2 | Waffenfamilie wechseln (Prototyp) |
| F1 / F2 / F3 / F5 | Debug: Hitboxen, Gegner spawnen, Mastery-Knoten, Arena zurücksetzen |

Kein Sprint.

## Bewegung
- Unmittelbar und präzise, Bewegung unabhängig von der Zielrichtung.
- Startwerte (Daten: `data/player/movement_config.tres`): 180 px/s, Light-Attack 85 %, Heavy-Charge 55 %.
- Keine träge Beschleunigung (Standard: volle Geschwindigkeit nach ~3 Frames).
- Diagonalbewegung ist nicht schneller als Achsenbewegung.

## Dash (`data/player/dash_config.tres`)
- 2 Ladungen, 300 ms Bewegung, 180 ms iFrames (ab Dash-Beginn), 2,5 s Regeneration pro Ladung,
  sequentiell (immer nur eine Ladung lädt).
- Richtung aus WASD; ohne Bewegungseingabe rückwärts relativ zur Mausrichtung.
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
- **Hitstop** ist eine Feel-Schicht (globales `Engine.time_scale`), begrenzt auf 0,15 s pro Treffer.
- **Spieler-Leben (Phase F):** 100 HP, bei 0 HP nach 1,5 s Respawn am Startpunkt (Prototyp-Lösung).
- **Gegner-Knockback** = `HitData.knockback × (1 − Resistenz) × knockback_scale` (Daten: `grunt_config.tres`).

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

## Vorschläge für den Feel-Test (NICHT umgesetzt)
- Light-Treffer auf Gegner wirken mit ~3 px Knockback evtl. zu weich → `knockback_scale` testen.
- Reaktionsdauern (v. a. STUN 0,6 s) im Kampf gegen mehrere Grunts prüfen.
- Dash durch Gegner erlauben? (siehe offene Designfragen)
- Hitstop-Gefühl jetzt lokal: prüfen, ob schwere Treffer weiterhin „Gewicht“ haben.
