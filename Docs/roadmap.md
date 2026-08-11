# LivingWorldSandbox roadmap

Ez a dokumentum a projekt központi, folyamatosan karbantartott roadmapje. Minden
feature lezárásakor frissíteni kell a státuszt, röviden le kell írni a tényleges
megoldást, és hivatkozni kell az ellenőrzésre vagy a részletes designra.

## Jelölések

- [x] elkészült és ellenőrzött;
- [ ] még nincs kész;
- **Részben kész**: működő alap van, de ismert részfeladat maradt;
- **Blokkolt**: az SDK vagy a motor jelenlegi korlátja akadályozza.

## Stabil alap és build

- [x] **Stabil induló ökoszisztéma** — egy Palace, 6 starter lair és 24 starter
  roaming monster. A bootstrap retry-limittel helyezi el őket, a baseline teszt
  pedig ellenőrzi a darabszámokat és a szükséges questfájlokat.
- [x] **Read-only SDK build** — a repository nem módosítja az SDK-t. A szükséges
  Northern Expansion függvény-override-ok buildidőben generálódnak a helyi
  SDK-forrásból.
- [x] **Kész, másolható csomagok** — az `output/LivingWorldSandbox` és
  `output/LWSCombatDiagnostic` allowlist alapján készül, nem kell forrásfájlokat
  kézzel válogatni.
- [x] **CI/CD fordítás és regresszió** — hosted runneren futnak a statikus és
  csomagtesztek; a konfigurált `majesty-sdk` runner reprodukálja a BCD-ket.

## Monster progression

- [x] **Egyedi monster state** — minden példány külön tárolja a levelt, kill
  számlálókat, building killt, progression classt és perk countot. Az init
  idempotens.
- [x] **Progression classok** — a Northern Expansion `LevelXP` értékéből számolt
  Starter/Low/Medium/High/Brutal kategóriák, a speciális 0 XP egységek kizárásával.
- [x] **Kill thresholdok és level-up** — classonként külön killgörbe, a natív
  látható experience level szinkronizálásával.
- [x] **Statnövekedés** — levelenként MaxHP, accuracy, Dodge és Parry; ritkábban
  Strength és Magic Resistance. A level-up csak a MaxHP-növekményt adja az
  aktuális HP-hoz, ezért nem full heal.
- [x] **Melee/ranged fatal-hit attribution** — a generált Northern Expansion
  `damage()` override közvetlenül a végső HP-módosítás előtt ad kill creditet.
- [x] **Közvetlen spell attribution** — a `spelldamage()` ugyanazt a fatal-hit
  csatornát használja; enemy kill számít, friendly Monster Player kill nem.
- [ ] **Poison/DOT/effect attribution** — **Blokkolt.** A vanilla periodikus HP
  drain nem tartja meg megbízhatóan a sebzés forrásagentjét. Új engine-hook vagy
  biztonságos saját DOT-state szükséges.

## Building destruction és perkek

- [x] **Külön building destruction attribution** — player building számít,
  monster lair és normál unit kill nem.
- [x] **Permanent stat perkek** — 35% production esély; combat, defense és magic
  ág; monsterenként legfeljebb három perk, statcapekkel.
- [ ] **Monster-safe ability perkek** — előbb SDK-audit és célzott aréna kell.
  Csak olyan meglévő ability használható, amelyet a vanilla monster AI valóban
  aktiválni és kezelni tud.

## Equipment modell

- [x] **Northern Expansion kompatibilitási mátrix** — 17 hősosztály, 9 weapon és
  4 armor family; minden nem engedélyezett family explicit tiltott.
- [x] **Tier és affix szétválasztása** — T1–T4 alapminőség és külön `+N` affix.
  A tényleges power fegyvernél egyszeres, armornál a natív magic-bónusz miatt
  kétszeres affixsúllyal számolódik.
- [x] **Common–Epic power budget** — a rarityt a tier és affix közös effektív
  értéke határozza meg; az átmeneti tier/affix kombinációk engedélyezettek.
- [x] **Blacksmith-integráció** — a kovács a tiert javítja, az affixet megtartja.
  A hős vásárlási döntését nem blokkolja egy nagy affix.
- [x] **Jobb equipment kiválasztása** — effektív power, majd döntetlennél affix
  és tier alapján történik.
- [ ] **Mágikus equipment-dimenzió** — külön structural/magical súlyozás és
  generálási szabály még nincs véglegesítve.
- [ ] **Lecserélt vagy gyengébb equipment sorsa** — eladás, salvage, tárolás vagy
  hősönkénti ignore-memory közül végleges megoldást kell választani.
- [ ] **Végleges tiernevek és affixeloszlás** — a működő számítás balanszolása és
  játékosnak szánt elnevezése hátravan.

## Monster loot

- [x] **Központi resolver és maximum két jutalom** — minden lootcsatorna ugyanazt
  a két slotot használja, és a fatal-hit resolver csak egyszer fut.
- [x] **Class alapú rarity-plafon** — C1 Common; C2 Common–Uncommon; C3
  Uncommon–Rare; C4 Rare–Epic; C5 Epic és whitelistelt Legendary esély. A monster
  saját levelje nem lépheti át a classt.
- [x] **Drop chance** — potion, weapon és armor külön 8%; C2–C4 esetén 75/25
  alsó/felső rarity; C5 garantált equipment, 1% whitelistelt Legendary csere.
- [x] **Healing Potion** — a natív potion countert növeli, a vanilla ötös capet
  betartja, és a normál `heal_self` használja el.
- [x] **Equipment-generátor** — statikus, compiler-safe katalógus 422 látható
  weapon/armor kombinációval.
- [x] **Első Legendary katalógus** — hat előre definiált Unique artifact,
  hősönként egyszeri permanent abilityvel és Class 5 source whitelisttel.
- [x] **Chest-alapú monster loot** — egy monster legfeljebb egy chestet hagy,
  benne összesen legfeljebb két jutalommal. A rarity/tier/affix a monster
  halálakor zárolódik; csak a family igazodik a chestet nyitó hőshöz. Paladin és
  Ranger kézi teszttel igazolva.
- [ ] **Monster level hatása a ligán belüli esélyre** — a rarity-plafon marad,
  de egy veterán példány jobb eredményének valószínűsége még nincs bevezetve.
- [ ] **További consumable és special item dropok** — a központi slotrendszer
  támogatja őket, de konkrét lista és viselkedés még nincs.
- [ ] **További Legendaryk** — csak előre gyártott, egyedi névvel és képességgel
  rendelkező tárgy kerülhet a katalógusba.

Részletes szabályok:

- [monster-loot-policy.md](monster-loot-policy.md)
- [equipment-rarity.md](equipment-rarity.md)
- [equipment-generator.md](equipment-generator.md)
- [legendary-catalog.md](legendary-catalog.md)

## Chest és exploration rendszer

- [x] **Zárolt chest-recept** — maximum két slot; equipment, potion, gold vagy
  Legendary jutalom; opener-kompatibilis equipment family.
- [x] **Natív chestnyitás megőrzése** — az animáció, hang, XP és cleanup vanilla;
  az LWS jutalom közvetlenül a cleanup előtt oldódik fel.
- [x] **Paladin/Ranger proof-of-concept** — ugyanaz a mechanika a Paladinnak
  Longsword/Plate, a Rangernek Longbow/Leather jutalmat adott.
- [x] **Exploration chest pályagenerálás** — egyszeri 12 chest, `8× C1 + 4× C2`,
  maximum Uncommon rarityvel, a Palace-tól számított 1/4–1/3 távolsági sávban.
- [x] **Chest UI döntés** — egyedi UI nem készül; a natív `Treasure_Chest` cím és
  objektumtípus megmarad az AI-felismerés biztonsága érdekében.
- [x] **Chest életciklus és takarítás** — a chest nyitásig megmarad, utána a natív
  engine törli; nincs utánpótlás, ezért nincs hosszú távú felhalmozódás.
- [x] **Használhatatlan vagy gyengébb chest-jutalom** — Healing Potion, teljes
  potionkészletnél pedig a natív 50–149 gold fallback.

Részletek: [exploration-chests.md](exploration-chests.md).

## Potion of Luck — későbbi custom item

- [ ] **Potion of Luck alapdesign** — **Tervezésre vár.** Vásárolható buffital,
  amely minden opcionális monster-loot csatorna saját drop chance-ét növeli. A
  rarity-, tier- és affixeloszlásokat, valamint a monster class rarity-plafonját
  nem módosíthatja.

Rögzített kezdőszabályok:

| Potion | Csatornánkénti alap drop chance | Buffolt drop chance csatornánként |
|---|---:|---:|
| Level 1 | 8% | 16% |
| Level 2 | 8% | 20% |
| Level 3 | 8% | 24% |

- [ ] **Marketplace kínálat** — minden Marketplace-szinten az adott Potion of
  Luck szint válik elérhetővé. Magasabb szintű Marketplace az alacsonyabb
  potionöket is kínálja, hogy a hős pénzétől függően olcsóbb változatot
  választhasson.
- [ ] **Healing Potion elsőbbsége** — a Marketplace vásárlási AI-ban a Healing
  Potion marad az elsődleges fogyóeszköz. A Potion of Luck csak akkor versenyezhet
  a hős pénzéért, ha az életben maradáshoz szükséges potionigény már teljesült.
- [ ] **Trading Post kínálat** — kizárólag Level 3 Potion of Luck vásárolható,
  pontosan ugyanazon az áron, mint a Marketplace Level 3 változata.
- [ ] **Árazás** — előbb SDK-audittal meg kell állapítani a natív Healing Potion
  árát és a hősök vásárlási feltételeit. A három Luck Potion ára csak ehhez
  viszonyítva tervezhető meg.
- [ ] **Buffmechanika SDK-audit** — a speed potion, Dirgo Strength és más,
  shopban vásárolható ideiglenes buffok purchase/transfer/effector mintáját kell
  feltérképezni és biztonságosan újrahasználni. A buff időtartama, halmozódása,
  újravásárlása és halál utáni viselkedése még nincs eldöntve.
- [ ] **Marketplace és Trading Post UI-audit** — meg kell vizsgálni, hogy az új
  vásárlási elem adatból bővíthető-e, generált GPL/UI override szükséges-e, vagy
  a kezelőfelület engine/BCD korlátba ütközik.
- [ ] **Loot pipeline bekötés** — a buff a potion, weapon, armor és minden későbbi
  opcionális droptípus külön chance-rolljára érvényesül. Egy Level 2 potion
  például mindegyik 8%-os csatornát külön-külön 20%-ra emeli. A sikeres
  jutalmakat továbbra is a közös maximum két slot korlátozza és egyetlen chest
  csomagolja; a rarity/tier/affix rollok százalékai változatlanok maradnak.

Az implementáció előtt külön designbeszélgetés és célzott tesztaréna szükséges.

## Sandbox világ és hosszú távú feature-ök

- [ ] **Dynamic lair director** — a világ aktivitásához igazodó lair-kezelés.
- [ ] **Lair regrowth** — lerombolt lairek kontrollált visszatérése.
- [ ] **Stage progression** — a sandbox nehézségének és tartalmának hosszú távú
  szakaszolása.
- [ ] **Final boss objective** — későbbi végjáték-cél, a sandbox emergens
  fejlődéséhez igazítva.
- [ ] **Hosszú játék balanszteszt** — lootmennyiség, veterán monster erő,
  gazdaság, pályaszemét és teljesítmény többnapos játékmenetben.

## Tesztelési és release-szabályok

- [x] A diagnosztika PASS esetén továbbra is `+7777` treasury goldot ad.
- [x] A lezárt kézi arénák nem maradnak a normál vagy diagnosztikai pályán.
- [ ] Minden új feature saját célzott arénát kap, amelyet a bizonyítás után
  vissza kell bontani.
- [ ] A `release/0.2.0` csak teljes regresszió és zöld CI után kerülhet `main`-re,
  külön felhasználói jóváhagyással.

## Következő döntési pont

A chest proof-of-concept lezárult. A következő feature megkezdése előtt ebből a
roadmapből kell kiválasztani a scope-ot, majd ahhoz külön feature ágat és célzott
tesztarénát létrehozni.
