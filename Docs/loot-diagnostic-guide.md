# Loot diagnostic tesztútmutató

## Automatikus runtime ellenőrzés

Másold az `output/LWSCombatDiagnostic` teljes tartalmát a játék questmappájába,
majd indítsd el az `LWS Combat Diagnostic` küldetést.

A quest harc és játékosi beavatkozás nélkül ellenőrzi:

- mind a 9 fegyvercsalád runtime kiválasztását;
- mind a 4 páncélcsalád runtime kiválasztását;
- mind a 6 Legendary katalógus-hozzárendelését;
- két world drop sikerét és a harmadik blokkolását;
- a korábbi progression-, perk-, potion- és spell-attribution teszteket.

Az automatikus rész nem spawnol valódi hősroster-t, ezért nem generál tesztházakat.
Az eredmény:

- induló 10000 goldból **17777**: minden automatikus ellenőrzés PASS;
- induló 10000 goldból **10111**: legalább egy ellenőrzés FAIL.

## Vizuális aréna

A kézi Paladin-, Ranger-, equipment- és chest-arénákat a sikeres ellenőrzés után
eltávolítottuk. A diagnosztikai pálya nem hagy maga után tesztépületeket, hősöket,
mobokat, tárgyakat vagy előre elhelyezett chesteket. A következő feature saját,
célzott arénát kap.
