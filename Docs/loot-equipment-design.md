# Loot- és felszerelésrendszer – alapdesign

> A rarity-, T1- és végleges power-szabályokat a
> [equipment-rarity.md](equipment-rarity.md) és az
> [equipment-rarity.json](equipment-rarity.json) tartalmazza. E dokumentum korábbi
> példáiban szereplő T2–T4-only és azonos fegyver/páncél affix-súlyozás elavult.

## Státusz

Ez a dokumentum a LivingWorldSandbox későbbi drop-, loot- és felszerelésrendszerének első rögzített tervezési döntését tartalmazza. Az itt leírt modell lesz az alap, amikor elkészítjük a további tárgytípusokat és a drop listákat.

Ez még design, nem kész implementáció.

## Cél

A felszerelés minőségi tierje és az egyedi tárgybónusza két külön tulajdonság legyen.

Ezzel elérhető, hogy:

- egy alacsonyabb tierű, de kivételesen jó drop ideiglenesen jobb lehessen egy magasabb tierű átlagos tárgynál;
- a hősnek magas `+` érték mellett is legyen oka felkeresni a Blacksmitht;
- a Blacksmith a tárgy alapminőségét fejlessze, ne törölje vagy írja felül annak egyedi bónuszát;
- ugyanaz a modell később fegyverekre, páncélokra és mágikus módosítókra is alkalmazható legyen.

## Fogalmak

### Tier

A tier a tárgy alapanyagát vagy gyártási minőségét jelöli.

A tervezett sorrend:

1. `T2` – alapminőség, például bronze; megfelel a Blacksmith LVL 2 kutatásának
2. `T3` – fejlesztett minőség; megfelel a Blacksmith LVL 3 kutatásának
3. `T4` – legjobb hagyományos Blacksmith-minőség; megfelel a Blacksmith LVL 4 kutatásának

A nagyobb tierszám jobb minőséget jelent: `T4 > T3 > T2`.

### Affix bonus

Az affix bonus a tárgy saját, droppal kapott egyedi értéke. A tárgy nevében ez jelenik meg `+N` formában.

Példák:

- `T2 Armor +6`
- `T3 Longsword +2`

Az affix nem azonos a tierrel, és Blacksmith-fejlesztéskor alapértelmezés szerint nem változik.

### Tényleges harci érték

A motor által használt tényleges structural érték a tier alapértékéből és az affixből áll össze:

```text
EffectiveStructuralBonus = TierBaseBonus + AffixBonus
```

Kezdeti tieralapok:

| Tier | Alap structural bónusz |
|---|---:|
| T2 | +1 |
| T3 | +2 |
| T4 | +3 |

Ezek kezdeti balanszértékek; tesztelés után módosíthatók anélkül, hogy az adatmodell megváltozna.

## Tárgycsere

Loot felvételekor a hős nem önmagában a tiert vagy az affixet vizsgálja, hanem a felszerelt és a talált tárgy teljes harci értékét hasonlítja össze.

Alapesetben a jobb tényleges értékű tárgyat szereli fel.

Példa:

| Tárgy | Tieralap | Affix | Tényleges structural érték |
|---|---:|---:|---:|
| felszerelt `T3 Armor +2` | 2 | 2 | 4 |
| talált `T2 Armor +6` | 1 | 6 | 7 |

Ebben az esetben a hős lecseréli a `T3 +2` páncélt a `T2 +6` páncélra, mert `7 > 4`.

Az azonos összértékű tárgyaknál az affix, majd a tier dönt. A Wizard Guild
enchant nem része a földi tárgy saját értékének, ezért nem akadályozhatja meg egy
valóban jobb tier+affix kombináció felszerelését.

## Blacksmith-fejlesztés

A Blacksmith látogatásának szükségességét nem a tárgy teljes `+` értéke, hanem annak külön tárolt tierje határozza meg.

Ez eltér a vanilla működéstől, amely csak a hős `Armor_Struct_Bonus` vagy `Weapon_Struct_Bonus` értékét vizsgálja, és `+3` felett már nem keres további fejlesztést.

Az új döntési logika:

1. A hős ellenőrzi a felszerelt tárgy tierjét.
2. Megvizsgálja, hogy egy elérhető Blacksmith képes-e ennél jobb tiert készíteni.
3. Ha képes rá, a hősnek van elég pénze, és az AI vásárlási feltételei teljesülnek, felkeresi a Blacksmitht.
4. A Blacksmith egy szinttel javítja a tárgy tierjét.
5. A tárgy affixe változatlan marad.
6. A rendszer újraszámolja a motor által használt tényleges structural bónuszt.

Példa:

```text
T2 Armor +6 -> T3 Armor +6 -> T4 Armor +6
```

A kezdeti tieralapokkal:

```text
T2 +6 = 7 structural
T3 +6 = 8 structural
T4 +6 = 9 structural
```

A Blacksmith tehát a tiert fejleszti, nem alakítja a `T2 +6` tárgyat `T3 +7` tárggyá. Így megmarad a különbség a tárgy droppal szerzett egyedi affixe és a kovácsolással javított alapminősége között.

## Tervezett belső adatmodell

A Majesty eredetileg nem teljes értékű, különálló felszerelési tárgyként kezeli a hős használt fegyverét és páncélját. Emiatt a modnak külön kell tárolnia legalább az alábbi adatokat:

```text
EquipmentType
EquipmentTier
EquipmentAffixBonus
ArmorEnchantBonus
```

A vanilla harcrendszerrel használt attribútumokat ebből kell kiszámítani és szinkronizálni. A tier kizárólag a structural mezőbe kerül, mert az eredeti Northern Expansion UI ebből képezi a fegyver minőségi nevét. Az affix a hős eredeti alap fegyversebzéséhez adódik:

```text
Armor_Struct_Bonus
Armor_Magic_Bonus = EquipmentAffixBonus + ArmorEnchantBonus
Weapon_Struct_Bonus
Weapon_Magic_Bonus
WeaponBasicDamage = OriginalWeaponBasicDamage + EquipmentAffixBonus
```

A hős kasztja továbbra is meghatározza a használható alap felszereléstípust, például a Paladin a saját engedélyezett fegyver- és páncéltípusát használja. A loot ennek egy tierrel és affixekkel ellátott változata lesz.

## Rögzített döntések

- A tier és a `+N` affix külön adat.
- A tárgy felvételét a teljes effektív harci érték dönti el.
- A Blacksmith látogatását a tier motiválja, nem a teljes bónusz.
- A Blacksmith-fejlesztés javítja a tiert, de megtartja az affixet.
- A hagyományos tiersorrend a játék kutatási szintjeit követi: `T2 -> T3 -> T4`.
- Nem készül külön generált mágikus loot-dimenzió.
- A Wizard Guild enchant külön, `0..3` közötti fejlesztési réteg.
- Armornál a natív magic mező az affix és a Wizard Guild enchant összege.
- A Blacksmith és az armorcsere megtartja a már megvásárolt enchantot.
- A további tárgyak és drop listák erre a modellre épülnek.

## Később eldöntendő kérdések

- A fegyverek és páncélok pontos tiernevei.
- Az affixek lehetséges minimuma, maximuma és eloszlása.
- Döntetlen értékű tárgyak kezelése.
- A lecserélt felszerelés sorsa: eldobás, eladás, tárolás vagy megsemmisítés.
- Artifact tárgyak és a hagyományos `T4` fölötti kategóriák.
- Treasure chestek és szörnyek külön drop táblái.
- Fegyver- és páncéltípusonkénti kompatibilitási szabályok.
