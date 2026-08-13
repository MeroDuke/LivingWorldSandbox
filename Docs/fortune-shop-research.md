# Fortune Shop kutatási jegyzet

## Cél és hatókör

Ez a dokumentum a Potion of Luck számára tervezett új épület, a munkanéven
**Fortune Shop** technikai megvalósíthatóságát rögzíti. Nem implementáció és nem
ígéret: a bizonyított SDK-képességeket, az engine-korlátokat, valamint a szükséges
proof-of-concept lépéseket választja szét.

A kutatás clean-room elven készült. Külső projektből nem került át forráskód,
szöveg, táblázat vagy grafikai/hang asset. Az implementáció alapja kizárólag a
repository read-only SDK-ja és a saját futásidejű kísérleteink lehetnek.

## Rövid döntés

Az új épület **adatoldalon támogatott**, de a sandbox/Freestyle kompatibilitás
még nem bizonyított. A feature csak akkor folytatható, ha egy minimális,
funkció nélküli Fortune Shop:

1. megjelenik a build menüben;
2. parasztokkal normálisan felépíthető;
3. megnyitja a kiválasztott natív bolti panelt;
4. több egymást követő sandbox-indításnál és mentés/betöltésnél stabil;
5. nem írja felül vagy töri el a meglévő LWS tartalmat.

## SDK-val bizonyított épületmodell

Az SDK hivatalos `WrathOfKrolm_Buildings.xml` példája új building descriptiont
definiál saját ID-val és GPL prototype-pal. Ez bizonyítja, hogy új unit/building
típus regisztrálható. A példa nem játékos által építhető bolt, ezért a build
menüt és a vásárlási felületet önmagában nem bizonyítja.

A Northern Expansion `MX_Buildings.xml` Magic Bazaar rekordja használható
referenciamodellként:

| Tulajdonság | Magic Bazaar referencia | Fortune Shop cél |
|---|---|---|
| Building ID | négykarakteres ID | saját, ütközésmentes ID |
| `Menu` | build-menü kategória | a megfelelő játékosi kategória |
| `ImageIDBase` | épületgrafika kulcsa | saját vagy ideiglenesen klónozott art |
| `DialogID` | `MX02` | első PoC-ban `MX02` újrahasznosítása |
| `Cost` | 1400 | később balanszoljuk |
| `UpgradeTo` | három épületszint | három Fortune Shop szint a cél |
| magasabb szintek | `NotBuildable` | csak upgrade útvonalon érhetők el |

Az első szint nem kaphat `NotBuildable` flaget. A második és harmadik szintet
nem külön építményként, hanem upgrade-ként kell elérni.

## Build menü és BDEP

A build menü láthatósága nem pusztán a building XML következménye. A játék a
`DATA/BDEP` building-dependency táblát is használja a Palace-szint és más
előfeltételek kiértékelésére.

Fontos engine-viselkedés:

- a BDEP teljes rekordként töltődik, nem soronként egyesül;
- két, saját BDEP-et szállító mod felülírhatja egymást;
- az LWS nem csomagolhat vakon egy másik projektből származó teljes BDEP-et;
- a saját build folyamatnak az installált, eredeti táblából kell reprodukálhatóan
  előállítania a kibővített változatot;
- a generátor ellenőrizze, hogy a saját szabály pontosan egyszer szerepel, és az
  eredeti szabályok változatlanok maradtak.

A Fortune Shop Palace-követelménye még design-döntés. A technikai PoC során a
lehető legkorábban elérhető, egyszerű feltételt kell használni, mert ekkor a
láthatóság és az építhetőség könnyen ellenőrizhető.

## Bolti panel és UI

Az engine nem kínál általános, tetszőleges callbackekkel bővíthető UI-frameworköt.
A `DialogID` egy executable által ismert panelviselkedést választ ki. Emiatt az
első reális út egy meglévő bolti handler újrahasznosítása.

A Magic Bazaar `MX02` a legjobb jelölt, mert:

- három épületszinttel rendelkezik;
- kutatható és megvásárolható consumable termékeket kezel;
- a hős inventory/spell alapú egyszer használatos potion útvonalához illeszkedik;
- a natív hős-AI már tud ilyen épületet és terméket felkeresni.

A PoC-ban először nem Potion of Luck készül. Egy meglévő, biztonságos terméket
és átnevezett panelmezőt használunk annak bizonyítására, hogy a klónozott
building saját `MX02` panellel stabilan működik.

Nyitott kérdések:

- a panel szövegei és hat termékhelye külön rekorddal biztonságosan
  namespacelhetők-e;
- elrejthető-e a nem használt három termékhely;
- ugyanaz a DialogID két külön épületpéldánynál saját inventoryt és research
  állapotot kezel-e;
- a vásárlási AI title, building type vagy konkrét Magic Bazaar azonosító alapján
  keres-e;
- a Fortune Shop és az eredeti Magic Bazaar együttes jelenléte okoz-e célpont-
  vagy készletkeveredést.

## CAM és grafikai pipeline

Egy valóban új épülethez legalább az alábbi vizuális állapotokra szükség van:

- build-menü ikon;
- placement/foundation és construction fázisok;
- aktív épület három szinten;
- sérült állapotok;
- összeomlás és rom;
- building panel portré/háttér;
- paletta- és árnyékkezelés.

A CAM rekordok indexalapúak lehetnek. Egy magas TILE index használata esetén az
alatta lévő üres slotokat is szerkezetileg meg kell tartani; ez nem jogosít fel
stock payloadok becsomagolására. A saját generátor csak a szükséges egyedi
payloadokat írhatja, a köztes slotok pedig üres bejegyzések legyenek.

Minden custom ID, text key, image, TILE, palette és panelrekord legyen LWS-
névtérben. A generátor készítsen ütközésvizsgálatot és allowlistes csomagellenőrzést.

## Sandbox/Freestyle kockázat

Külső, nyilvános kísérleti projekt arról számol be, hogy a custom CAM providere
Original/Northern questekben működik, Freestyle indításkor viszont összeomlást
okoz. Ez nem bizonyítja, hogy minden custom CAM hibás Freestyle-ban, de az LWS
számára blokkoló kockázat, mert a projekt elsődleges játékmódja sandbox.

Ezért a CAM-komponenseket fokozatosan kell bekapcsolni:

1. building XML + GPL, stock vizuális hivatkozással;
2. külön text provider;
3. build-menü ikon;
4. building world art;
5. panel art;
6. végül hang és további effekt.

Minden lépcső után legalább öt új sandbox-indítás, restart és mentés/betöltés
szükséges. Az első crashnél az utoljára hozzáadott provider külön izolálandó.

## Potion of Luckhoz szükséges későbbi integráció

Ha az épület/UI PoC stabil, csak utána következhet:

- három kutatható Potion of Luck termék;
- árak a natív 25 goldos Healing Potionhoz viszonyítva;
- Healing Potion vásárlási prioritásának megőrzése;
- L1/L2/L3 buff-élettartam és újraalkalmazási szabály;
- 16/20/24%-os opcionális lootcsatorna-esély;
- rarity, tier, affix és class cap változatlanul hagyása;
- Trading Post L3 kínálat külön vizsgálata;
- death/save/load/stack cleanup.

## Stop/go kapuk

| Kapu | Go feltétel | Stop feltétel |
|---|---|---|
| A: épületadat | saját épület spawnol és építhető | unit/building regisztráció instabil |
| B: build menü | ikon és Palace-feltétel determinisztikus | BDEP vagy ikon nem izolálható |
| C: panel | saját épületből stabil `MX02` panel | stock Bazaar állapota keveredik |
| D: sandbox | ismételt start és save/load stabil | reprodukálható Freestyle crash |
| E: termék | egy teszt consumable kutatható és vehető | UI/AI nem címezhető külön |
| F: Luck | buff és loot roll helyesen működik | stack/cleanup vagy AI beragadás |

## Elsődleges helyi referenciák

- `Sdk/Example/Data/WrathOfKrolm_Buildings.xml`
- `Sdk/Example/GPL/WrathOfKrolm_Data.dat`
- `Sdk/OriginalQuests/DataMX/MX_Buildings.xml`
- `Sdk/OriginalQuests/GPLMx/TaskModules/Buildings/Magic_Bazaar.gpl`
- `Sdk/OriginalQuests/GPLMx/TaskModules/Buildings/mx_Shop_Visited.gpl`
- `Sdk/OriginalQuests/GPLMx/DecisionTrees/Modules/mx_Purchase_Equipment.gpl`
- `GPL/LWS_Loot.gpl`

## Külső kutatási előzmény

A technikai kockázatok felismerését a nyilvánosan elérhető
[Phantoms Haunt projekt](https://github.com/Phantomstar721/majesty-gold-hd-custom-guild-phantoms-haunt)
tanulmányozása segítette (hozzáférés: 2026-08-13). A repositoryban nem volt
azonosítható licenc, ezért sem kódot, sem dokumentációt, sem assetet nem veszünk
át belőle. A jelen jegyzet saját megfogalmazású követelmény- és kockázatleírás;
minden implementációt az SDK-ból és saját tesztekkel kell újra levezetni.

