# Exploration chestek

Az LWS chest egyetlen földi objektumba legfeljebb két jutalmat csomagol. A két
külön korlát változatlanul érvényes: egy forrás legfeljebb két jutalmat adhat, és
egy monster legfeljebb egy chestet hozhat létre.

## Zárolás

A chest létrejöttekor véglegesen eldől:

- a chest class (C1–C5);
- a jutalmak száma (1–2);
- minden felszerelés rarityje, tierje és affixe;
- a potion-, gold- vagy Legendary-jutalom.

A nyitó hős ereje ezeket nem módosítja. Emiatt egy C1 monsterből származó chest
nem adhat magasabb ligájú felszerelést akkor sem, ha egy magas szintű hős nyitja.

Kinyitáskor kizárólag a felszerelés familyje igazodik a nyitó Northern Expansion
kasztjához. A Paladin/Warrior Longswordot és Plate-et, a Ranger/Elf Longbow-t,
majd a saját armor-familyjét kapja. Ha a kaszt az adott slot típusát nem használja,
a jutalom kis aranykompenzációvá alakul.

## Források

- Monster chest: a `LWS_ProgressClass` adja a C1–C5 korlátot. A monster összes,
  legfeljebb két sikeres loot-rollja egy chestbe kerül.
- Exploration chest: a pályagenerátor adja a chest classt. A diagnosztikai pálya
  öt, a Paladintól távol elhelyezett C1–C5 chestet hoz létre.

A gyári `Open_Chest` továbbra is kezeli az animációt, hangot, XP-t és törlést. Az
LWS build a read-only SDK-forrásból generált override-on keresztül, közvetlenül a
gyári cleanup előtt oldja fel a zárolt jutalmakat.
