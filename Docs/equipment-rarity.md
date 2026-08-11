# Felszerelés-erő és ritkaság

Ez a szabályrendszer minden támogatott fegyvercsaládra és minden páncélcsaládra
(`Leather`, `Chain`, `Plate`, `Chaos`) érvényes. A kompatibilitást továbbra is a
kasztmátrix dönti el; a ritkaság nem írja felül, hogy ki mit viselhet.

## Erőérték

| Tier | Alaperő |
|---|---:|
| T1 – alap, fejlesztetlen | 0 |
| T2 – bronze | 1 |
| T3 – fejlesztett | 2 |
| T4 – legjobb normál Blacksmith-minőség | 3 |

```text
WeaponPower = TierBasePower + Affix
ArmorPower  = TierBasePower + 2 × Affix
```

A páncél kétszeres affix-súlya az eredeti Northern Expansion harci számítását
követi. A Blacksmith csak a tiert növeli (`T1 → T2 → T3 → T4`), az affixet
változatlanul hagyja.

## Ritkasági sávok

| Ritkaság | Erőérték |
|---|---:|
| Common | 0–1 |
| Uncommon | 2–3 |
| Rare | 4–6 |
| Epic | 7–10 |

A `Legendary` nem ennek a képletnek a következő sávja. Csak előre definiált,
névvel és külön jogosultsági szabállyal rendelkező Unique tárgy lehet Legendary.
Így egy közönséges szörny véletlenül sem generálhat legendás felszerelést.

## Tárgycsere

A hős csak kompatibilis felszerelést vizsgál. A választási sorrend:

1. nagyobb teljes erőérték;
2. azonos erőnél nagyobb affix, mert ez több Blacksmith-fejlesztési potenciált őriz;
3. azonos affixnél nagyobb tier.

Például a `T1 +3` és a `T2 +2` fegyver egyaránt 3-as, Uncommon erőértékű.
Közülük a `T1 +3` nyer az affix miatt, és később a Blacksmithnél tovább erősödhet.

Az adatgéppel feldolgozható változat: `Docs/equipment-rarity.json`.
