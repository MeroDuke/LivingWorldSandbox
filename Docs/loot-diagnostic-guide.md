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

## Ideiglenes chest-aréna

PASS után a diagnosztikai pálya egy level 8 Paladint és egy Warriors Guildet
helyez el a Palace-tól távol. A Palace körül hét célzott chest jelenik meg:

1. Healing Potion;
2. 100 gold;
3. Legendary Unique;
4. Healing Potion + 100 gold;
5. gyengébb Common T1 weapon;
6. újabb Healing Potion;
7. az előzővel azonos Legendary Unique.

Egy külön Temple to Dauros mellett álló Monk közelében egy nyolcadik, weapon
jutalmú chest található. Mivel a Monk egyik LWS equipment-familyt sem használja,
ennek Healing Potion fallbacket kell adnia.

A Paladin négy Healing Potionnel és 1000+1000 golddal indul. Emiatt megfigyelhető
a potion cap utáni 50–149 gold fallback, a gyengébb equipment potionre váltása és
a duplikált Legendary fallbackje is. A chestek a Palace körül vannak, míg a gyors
Paladin távol indul, hogy legyen idő megkeresni és megfigyelni őket.

A normál production quest nem tartalmaz Paladint vagy Warriors Guildet; csak a
12 távoli, egyszer generált exploration chestet. A kézi ellenőrzés elfogadása
után ezt a diagnosztikai arénát ismét vissza kell bontani.
