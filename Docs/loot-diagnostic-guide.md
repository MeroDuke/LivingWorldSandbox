# Loot diagnostic tesztútmutató

## Automatikus runtime ellenőrzés

Másold az `output/LWSCombatDiagnostic` teljes tartalmát a játék questmappájába,
majd indítsd el az `LWS Combat Diagnostic` küldetést.

A quest harc és játékosi beavatkozás nélkül ellenőrzi:

- mind a 9 fegyvercsalád runtime kiválasztását;
- mind a 4 páncélcsalád runtime kiválasztását;
- mind a 6 Legendary katalógus-hozzárendelését;
- a maximum két jutalmas korlátot;
- a korábbi progression-, perk-, potion- és spell-attribution teszteket.

Az eredmény:

- induló 10000 goldból **17777**: minden automatikus ellenőrzés PASS;
- induló 10000 goldból **10111**: legalább egy ellenőrzés FAIL.

## Vizuális aréna

A Healing Potion, gold, Legendary, kétjutalmas chest, gyengébb és használhatatlan
equipment fallback, maximális potionkészlet és duplikált Legendary célzott kézi
tesztje sikeres volt. Az ideiglenes Paladin/Monk chest-arénát ezért eltávolítottuk.
A diagnosztikai pálya nem hagy tesztépületeket, hősöket vagy előre elhelyezett
kézi tesztchesteket.
