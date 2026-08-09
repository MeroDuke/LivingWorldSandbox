# Northern Expansion equipment compatibility

Az LWS loot-rendszer kizárólag a `MajestyExpansion` adatkészlet tényleges
`AllowedWeapon` és `AllowedArmor` mezőit tekinti hitelesnek. A géppel feldolgozható
forrás: `Docs/equipment-compatibility.json`.

| Hős | Viselhető fegyver | Viselhető páncél |
|---|---|---|
| Adept | Staff | Leather |
| Barbarian | Axeclub | nincs |
| Cultist | Dagger | Leather |
| Healer | Dagger | nincs |
| Monk | nincs | nincs |
| Paladin | Longsword | Plate |
| Priestess | Staff | nincs |
| Ranger | Longbow | Leather |
| Rogue | Crossbow | Leather |
| Solarus | Mace | Chain |
| Warrior | Longsword | Plate |
| Warrior of Discord | Chaos | Chaos |
| Wizard | Staff | nincs |
| Dwarf | Hammer | Plate |
| Elf | Longbow | Chain |
| Gnome | Dagger | nincs |
| Gnome Champion | Dagger | Leather |

Minden sorban minden fel nem sorolt family tiltott. A JSON ezt explicit `forbidden`
listákban is tárolja, így a későbbi dropgenerátor nem tud hallgatólagos kompatibilitást
feltételezni.

## Runtime szabály

Minden LWS equipment item kötelező mezői:

- `LWS_EquipmentType`: `Weapon` vagy `Armor`;
- `LWS_EquipmentFamily`: a JSON family-listáinak egyike;
- `LWS_EquipmentTier`;
- `LWS_EquipmentAffixBonus`.

A hős csak akkor vizsgálhatja és veheti fel az itemet, ha a type és family pontosan
egyezik a karakter Northern Expansion kompatibilitásával. A kompatibilitási vizsgálat
megelőzi a tier + affix összehasonlítást.

## Fontos következmények

- A Paladin és a Warrior közös Longsword- és Plate-dropokat használhat.
- A statikus dropok már a saját BirthScriptjükben megkapják a típus- és családbesorolást.
  Így a hős AI a tárgy megjelenésének első pillanatától kiszűrheti az inkompatibilis
  felszerelést; például a Paladin nem választhat Longbow dropot.
- A felszerelések világobjektum-típusa `LWS_EquipmentDrop`, nem `Special_Item`.
  Az eredeti hős-BCD-k közvetlen vanilla itemkeresése questből nem írható felül
  minden hívási útvonalon. A kompatibilis célpontot ezért az
  `LWS_EquipmentPickupDirector` választja ki; a potionök, Legendary tárgyak és
  treasure chestek továbbra is a játék eredeti `Special_Item` útvonalát használják.
- A Ranger és az Elf közös Longbow-dropokat használhat, de eltérő páncélt viselnek.
- A Healer és a Gnome használhat Daggert, de nem viselhet páncélt.
- A Monk sem fegyver-, sem páncéldroppot nem használhat.
- A Warrior of Discord `Chaos` equipmentje külön family, nem általános fegyver vagy páncél.
- A `Gnomechamp` Northern Expansion-kiegészítés; nem azonos a normál Gnome-nal.
