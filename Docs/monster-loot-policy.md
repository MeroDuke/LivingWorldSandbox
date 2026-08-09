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

A konkrét drop- és rarity-esélyek szándékosan nincsenek még rögzítve. A jelenlegi
8%-os Healing Potion esély átmenetileg változatlan marad a következő
balanszlépésig.
