# Random equipment generator

A production monsterdrop 422, az SDK SpecialItemsExample sémáját követő statikus
world-item prototípust használ. Mindegyiknél a Description `ID` és `Name` azonos;
a látható név és leírás a saját `HelpID` szövegéből érkezik. A resolver kizárólag
fordításkor látható literál prototípusazonosítókat ad vissza: nincs `SpecifyName`
és nincs futás közben összefűzött prototípusnév.

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
