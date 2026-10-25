# Game Vision – Echoes of the Hollow

**Genre:** 2D-Pixel-Art-Action-RPG mit modernen Effekten, schräge Top-Down-Perspektive.
**Engine:** Godot 4 / GDScript.

## Säulen
1. **Präziser, flexibler Nahkampf** – unmittelbare Bewegung, Maus-Zielrichtung, verzweigte Combos,
   großzügiges Animation-Cancelling per Dash.
2. **Build-Vielfalt auf einem Charakter** – alle Klassen auf einem Charakter freischaltbar und
   wechselbar, eigene Klassenlevel, Skills, Talentbäume, Waffenbeherrschung pro Waffenfamilie.
3. **Reagierende, persistente Welt** – handgestaltete Regionen mit mehreren Maps, Heimatbasis mit
   Bauplätzen, NPCs, Dungeons.
4. **Wiederspielbarkeit** – Dungeons und Bosse mit steigenden Schwierigkeitsstufen, Unique-,
   Legendary- und Set-Ausrüstung mit buildverändernden Effekten.

## Langfristiger Umfang (nicht Teil von Prototyp 0.1)
- Große Regionen mit Ladeübergängen, Heimatbasis mit vorgegebenen Bauplätzen
- NPCs, Crafting, Dungeons, Elitegegner, Bosse
- 5 Startklassen, später ≥ 15; Klassenlevel, Skills (Q/E/R/F), Talentbäume, defensiver Slot (Shift)
- Viele Waffenfamilien mit eigener Beherrschung (schaltet Combo-Knoten frei)
- Unique-Items, legendäre Ausrüstung, Set-Boni

## Prototyp 0.1
Ausschließlich der Combat-Kern: Bewegung, Dash, Light/Heavy-Angriffe mit Charge, Combo-Baum,
Cancelling, Treffer-System, Trainingspuppe, Debug-Overlay; optional zweite Waffenfamilie und ein
einfacher Nahkampfgegner. Zukünftige Systeme werden nur über klar benannte Erweiterungspunkte
berücksichtigt (siehe `ARCHITECTURE.md`).
