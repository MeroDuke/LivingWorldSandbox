# Loot diagnostic tesztútmutató

## Automatikus runtime ellenőrzés

Másold az `output/LWSCombatDiagnostic` teljes tartalmát a játék questmappájába,
majd indítsd el az `LWS Combat Diagnostic` küldetést.

A quest harc és játékosi beavatkozás nélkül ellenőrzi:

- mind a 9 fegyvercsalád generikus carrierét és kompatibilis hősre helyezését;
- mind a 4 páncélcsalád carrierét;
- mind a 6 Legendary átadását és permanens markerét;
- két world drop sikerét és a harmadik blokkolását;
- a korábbi progression-, perk-, potion- és spell-attribution teszteket.

Ezek a tesztalanyok automatikusan eltűnnek. Az eredmény:

- induló 10000 goldból **17777**: minden automatikus ellenőrzés PASS;
- induló 10000 goldból **10111**: legalább egy ellenőrzés FAIL.

## Rövid vizuális smoke arena

PASS/FAIL után megmarad:

- egy 8-as szintű Paladin;
- egy Warriors Guild;
- egy fejlesztés nélküli, harmadik szintű Blacksmith;
- egy runtime generált `T3 Longsword +1`;
- egy runtime generált `T3 Plate +1`;
- egy Wand of Immolation;
- négy gyenge Giant Rat biztonságosabb távolságban.

Szemmel csak azt kell figyelni, hogy a Paladin felveszi-e a közeli kompatibilis
tárgyakat, nem ragad-e bele a földi loot vizsgálatába, és a Legendary felvétele
után képes-e használni az új képességet. A 8%/1% természetes esélyeket ebben a
smoke tesztben nem kell kivárni.
