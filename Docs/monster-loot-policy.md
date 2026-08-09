# Monster loot policy

A monster alapvető lootligáját a már létező `LWS_ProgressClass` határozza meg.
A saját `LWS_Level` növelheti majd a jobb eredmény esélyét a ligán belül, de nem
emelheti meg a rarity-plafont.

| Progress class | Engedélyezett rarity |
|---:|---|
| 0 – Special | nincs normál drop |
| 1 – Starter | Common |
| 2 – Low | Common–Uncommon |
| 3 – Medium | Uncommon–Rare |
| 4 – High | Rare–Epic |
| 5 – Brutal | garantált Epic; whitelist esetén esély Legendary Unique-ra |

A Class 5 önmagában nem elég Legendary tárgyhoz. A forrásnak külön
`LWS_LegendaryLootSource` jelölést is kell kapnia.

Minden halott monster összesen legfeljebb két földi tárgyat hozhat létre. A
Healing Potion, weapon, armor és minden későbbi consumable vagy special item
ugyanazokat a slotokat használja. A központi resolver egyszer fut le halálkor,
és csak sikeresen létrehozott tárgy fogyaszt slotot.

## Drop chance

Az alap opcionális csatornák külön-külön 8%-os esélyt kapnak:

- Healing Potion: 8%;
- weapon: 8%;
- armor: 8%.

Sikeres equipment roll után külön rarity-roll fut:

| Class | Rarity-eloszlás |
|---:|---|
| 1 | 100% Common |
| 2 | 75% Common, 25% Uncommon |
| 3 | 75% Uncommon, 25% Rare |
| 4 | 75% Rare, 25% Epic |
| 5 | 99% Epic, 1% Legendary Unique |

A Class 5 egyetlen equipment jelöltje garantált. A sikeres 1%-os Legendary-roll
ezt az Epic tárgyat cseréli Unique-ra, nem hoz létre további world dropot.
