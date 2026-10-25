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
Langsamer, größere Reichweite, deutlich stärkere Heavies, eigene Combo-Definitionen.

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

## Offene Designfragen
- Mehrere Klicks innerhalb eines einzelnen Physik-Frames (16 ms) zählen als eine Eingabe. Bei 60 Hz
  praktisch irrelevant; falls nötig, Physik-Tickrate erhöhen.
- Player-Treffer-Reaktion (Stagger/Hyperarmor) ist im Design nicht definiert; Prototyp: Spieler wird
  nicht unterbrochen, erhält nur Schaden und Knockback.
