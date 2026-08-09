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

## Rövid vizuális smoke arena

PASS/FAIL után megmarad:

- egy 8-as szintű Paladin;
- egy 8-as szintű Ranger és a saját Rangers Guildje a chestek közelében;
- egy Warriors Guild;
- egy fejlesztés nélküli, harmadik szintű Blacksmith;
- négy gyenge Giant Rat biztonságosabb távolságban;
- öt C1–C5 exploration chest közvetlenül a kastély körül.

Szemmel azt kell figyelni, hogy a kastély körüli chesteket megtalálják-e a
felfedező hősök, a chest eltűnik-e nyitáskor, és a hős statjai, potionje vagy
aranya megkapja-e a lezárt jutalmat. A régi közvetlen Longsword, Plate, Longbow
és Legendary teszttárgyak már nem jelennek meg.
