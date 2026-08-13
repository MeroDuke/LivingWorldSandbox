# Fortune Shop proof-of-concept ellenőrzőlista

Ez a lista kizárólag a technikai megvalósíthatóságot vizsgálja. Nem tartalmaz
Potion of Luck balanszt vagy végleges grafikát.

## 0. Előkészítés

- [ ] Külön implementációs feature ág és jóváhagyott release-cél.
- [ ] Egyedi LWS building, text, image és GPL ID-tartomány kijelölése.
- [ ] A build csomagban semmilyen külső vagy engedély nélküli payload nincs.
- [ ] A jelenlegi stabil output hash/lista mentése regressziós alapnak.

## 1. Building regisztráció

- [ ] L1 Fortune Shop kézi spawnból létrejön.
- [ ] Kijelölhető, sérülhet és a natív cleanup eltávolítja.
- [ ] L2/L3 külön nem építhető, csak upgrade-cél.
- [ ] Save/load megőrzi a building szintjét és állapotát.

## 2. Build menü és construction

- [ ] A Fortune Shop pontosan a kívánt Palace-szinten jelenik meg.
- [ ] Más szinten nem jelenik meg.
- [ ] A build-menü ikon nem cserél le stock ikont.
- [ ] Placement működik.
- [ ] Parasztok felépítik és javítják.
- [ ] BDEP-generálás az eredeti teljes táblát megőrzi.

## 3. Shop panel

- [ ] Az épület a `MX02` panelt stabilan megnyitja.
- [ ] Az eredeti Magic Bazaar panelje változatlan marad.
- [ ] Legalább egy saját text key látható.
- [ ] Egy biztonságos teszttermék kutatható.
- [ ] A terméket hős meg tudja vásárolni és használni.
- [ ] A két épület research/inventory állapota nem keveredik.

## 4. Sandbox stabilitási kapu

- [ ] 5/5 új játék elindul.
- [ ] 5/5 restart elindul.
- [ ] Mentés/betöltés működik épület nélkül.
- [ ] Mentés/betöltés működik foundation állapotban.
- [ ] Mentés/betöltés működik kész L1/L2/L3 épülettel.
- [ ] Original és Northern Expansion célkörnyezetben is tesztelve.
- [ ] Nincs új crash, AI `Thinking` beragadás vagy build-menü regresszió.

## 5. CAM komponensenkénti izoláció

- [x] A hivatalos SDK példa-CAM fejlécét és IMAG/TILE/SPLT könyvtárait saját,
  read-only inspector határhelyesen visszaolvassa.
- [x] A konténer- és szekciókönyvtár szerkezete saját clean-room jegyzetben
  dokumentált (`majesty-cam-format-notes.md`).
- [x] A TILE oszlopos RLE és a SPLT paletta olvasható, két eltérő SDK tile-ból
  felismerhető, átlátszó PNG készül.
- [ ] A TILE fix fejléc fennmaradó mezői és az IMAG kapcsolat dokumentált.
- [x] Minimális saját TILE/SPLT encoder és byte-azonos CAM repacker elkészült.
- [x] Izolált, egyképes Curios and Charms CAM felépül és helyes PNG-re
  visszafejthető; az IMAG sablon engine-kompatibilitása még nem igazolt.
- [ ] Text provider önmagában stabil.
- [ ] Build ikon provider hozzáadása után stabil.
- [ ] World art provider hozzáadása után stabil.
- [ ] Panel art provider hozzáadása után stabil.
- [ ] Hang/effect provider hozzáadása után stabil.
- [ ] Minden lépcső után ismételt sandbox start és save/load megtörtént.

## 6. Go/no-go döntés

**Go:** minden 1–5. szakasz zöld, a Fortune Shop és az eredeti Magic Bazaar
egymás mellett stabil, a termék UI-ból kutatható és megvásárolható.

**No-go:** reprodukálható sandbox crash, nem izolálható BDEP/panel ütközés,
vagy a terméket nem lehet a játékos számára látható és használható UI-elemként
megvalósítani. No-go esetén a Potion of Luck jelenlegi shop-koncepciója blokkolt.
