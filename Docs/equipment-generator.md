# Random equipment generator

## Visible world-item names

Each generic carrier receives an instance-specific display name through the SDK
`SpecifyName` function. The label contains rarity, equipment family, tier, and
affix, for example `Uncommon Longsword T3 +1`. The stable prototype `Title`
remains unchanged, so pickup and transfer logic continue to use the original
carrier identifier.

A production monsterdrop két generikus world-item hordozót használ: egy fegyvert
és egy páncélt. Spawn után a GPL ráírja a konkrét családot, tiert, affixet és
rarityt. Ez elkerüli több száz statikus prototípus karbantartását.

A fegyverpool minden használható Northern Expansion családot tartalmaz:
`Staff`, `Axeclub`, `Dagger`, `Longsword`, `Longbow`, `Crossbow`, `Mace`,
`Chaos`, `Hammer`.

A páncélpool: `Leather`, `Chain`, `Plate`, `Chaos`.

A generátor előbb rarityt kap a monster loot policytól, majd csak olyan T1–T4
tier/affix párt készít, amelynek számított ereje az adott rarity sávjába esik.
A páncélgenerálás figyelembe veszi a kétszeres magic-affix szorzót.

Ha potion, weapon és armor egyszerre nyerné meg a saját rollját, a rendszer
véletlenszerűen hagy el egy jelöltet. Így egyik tárgytípus sem élvez állandó
sorrendi előnyt, és a két world-drop limit megmarad.

A Legendary nem használ generikus hordozót. A sikeres whitelistelt Legendary-roll
a külön, névvel rendelkező Unique katalógusból választ tárgyat.
