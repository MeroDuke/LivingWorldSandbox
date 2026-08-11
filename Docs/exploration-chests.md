# Exploration chestek

Az LWS chest egyetlen földi objektumba legfeljebb két jutalmat csomagol. A két
korlát változatlanul érvényes: egy forrás legfeljebb két jutalmat adhat, és egy
monster legfeljebb egy chestet hozhat létre.

## Zárolt recept

A chest létrejöttekor véglegesen eldől:

- a chest class (C1–C5);
- a jutalmak száma (1–2);
- minden felszerelés rarityje, tierje és affixe;
- a potion-, gold- vagy Legendary-jutalom.

A nyitó hős ereje ezeket nem módosítja. A felszerelés familyje viszont a nyitó
Northern Expansion kasztjához igazodik: például a Paladin/Warrior Longswordot és
Plate-et, a Ranger/Elf Longbow-t és a saját armor-familyjét kapja.

## Végleges jutalom-fallback

Ha egy equipment használható és tényleges fejlesztés, a hős felszereli. Minden
más esetben Healing Potion jár:

- a kaszt nem használja az adott equipmenttípust;
- a generált tárgy gyengébb vagy azonos a meglévőnél;
- a hős már birtokolja a chestben lévő Legendary Unique tárgyat.

Ha a hős már a natív maximumon tart Healing Potiont, a fallback a gyári treasure
chest aranyképlet: `50 + Random(100)`, vagyis 50–149 gold. Egy közvetlen potion
jutalom is erre az aranyra vált, ha a potionkészlet tele van. Így nincs jutalom
nélküli chestnyitás.

## Exploration generálás

A normál pálya indulásakor pontosan egyszer készül legfeljebb 12 exploration
chest:

- 8 darab C1;
- 4 darab C2;
- mindegyik 1 vagy 2 zárolt jutalmat tartalmaz;
- rarity-plafonjuk Uncommon;
- nem skálázódnak a pálya veszélyességével;
- nincs utánpótlás vagy újragenerálás.

A generátor futásidőben kiolvassa a pálya kiterjedését és a Palace helyét. A
Palace-tól a legtávolabbi sarok távolságának 75%-át használja minimális
spawn-távolságként, ezért a chestek a felfedezési terület külső részére kerülnek.
Az érvénytelen vagy foglalt terepet legfeljebb 120 próbálkozással kerüli el.

A chest nyitásig a pályán marad. Nyitás után a gyári `Open_Chest` kezeli az
animációt, hangot, XP-t és törlést. Nincs külön aktív-chest limit: az egyszeri,
12 darabos generálás miatt a rendszer önmagában nem halmoz fel új objektumokat.

## UI

Egyedi chest UI nem készül. A natív `Treasure_Chest` cím és objektumtípus
változatlan marad, mert a hősök AI-ja ezt használja a chest felismerésére.

## Ideiglenes kézi tesztaréna

A diagnosztikai quest ideiglenesen tartalmaz egy távoli level 8 Paladint és
Warriors Guildet, valamint egy elkülönített Monkot és Temple to Daurost. A
Palace körüli, illetve a Monkhoz tartozó célzott chestek lefedik:

- Healing Potion;
- gold;
- Legendary;
- kétjutalmas chest;
- gyengébb equipment fallback;
- maximális potionkészlet;
- duplikált Legendary fallback.

Az arénát a sikeres kézi teszt után vissza kell bontani; a production questben
nem szerepel.
