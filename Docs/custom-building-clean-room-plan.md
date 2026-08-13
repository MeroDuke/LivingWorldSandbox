# Custom building clean-room munkaterv

## Jogi és technikai határ

Az LWS custom building eszközeit saját magunk készítjük el. Licenc nélküli külső
repositoryból tilos átemelni:

- forráskódot vagy annak mechanikus átírását;
- dokumentációs mondatokat és táblázatokat;
- CAM payloadokat, stockból kinyert rekordokat vagy generált archívumokat;
- képet, sprite-ot, palettát, hangot vagy UI textúrát;
- egyedi azonosítókat és kreatív elnevezéseket.

Megengedett a nyilvánosan megfigyelt kompatibilitási probléma vagy engine-
viselkedés hipotézisként való feljegyzése, ha azt saját SDK-audittal vagy teszttel
újra igazoljuk. A külső kutatási előzményt nem rejtjük el.

## Saját előállítandó komponensek

| Komponens | Saját megoldás követelménye | Ellenőrzés |
|---|---|---|
| Building XML | saját ID-k és három upgrade-szint | schema/build validáció |
| GPL prototype | saját title és callbackek | compiler + spawn teszt |
| BDEP generator | eredeti SDK/install rekordból determinisztikusan | stock szabályok hash/összevetés |
| Text provider | kizárólag saját kulcsok és szövegek | ID-ütközés teszt |
| Build ikon | saját grafika vagy engedélyezett ideiglenes asset | build-menü kézi teszt |
| World art | saját készítésű teljes állapotkészlet | sprite/paletta validáció |
| Shop panel | SDK-ból levezetett, saját rekordgenerálás | UI és input teszt |
| Package builder | nulláról megírt CAM/XML/GPL pipeline | allowlist és reprodukálható build |

## Bizonyítási napló

Minden reverse-engineering eredményhez rögzítendő:

- melyik helyi SDK-fájl vagy saját bináris megfigyelés bizonyítja;
- a minimális reprodukció;
- az elvárt és tényleges eredmény;
- melyik engine-verzión és játékmódban történt;
- van-e Original/Northern/Freestyle eltérés;
- milyen csomagkomponens hozzáadása után jelent meg regresszió.

## Fejlesztési sorrend

1. **Adat-only épület:** saját building ID, stock ideiglenes art, kézi spawn.
2. **Építhetőség:** build-menü és BDEP, Palace-feltétel, construction lifecycle.
3. **Panel PoC:** `MX02` handler, egy meglévő teszttermék, saját szövegkulcs.
4. **Sandbox stabilitás:** ismételt start, restart, save/load, eredeti Bazaar mellett.
5. **Saját art pipeline:** először ikon, majd world art, végül panel.
6. **Potion product:** research, purchase, inventory, cast/consume.
7. **Luck buff:** effect state, timer, stack/refresh, cleanup.
8. **Loot-integráció:** csatornánkénti chance módosítás, kétjutalmas cap megtartása.

## Kötelező regresszió

- 6 starter lair és 24 starter mob baseline;
- exploration chest egyszeri generálás;
- monster loot maximum két jutalom;
- eredeti Marketplace, Trading Post és Magic Bazaar működése;
- eredeti Magic Bazaar kutatás és consumable vásárlás;
- paraszt construction/repair;
- Palace upgrade és build-menü frissülés;
- legalább öt egymást követő sandbox-start;
- save/load Fortune Shop építés közben és elkészülte után;
- Fortune Shop nélküli régi save betöltése.

## Licencellenőrzés

Ha később a külső projekt egyértelmű licencet kap, az sem teszi automatikussá az
átvételt. Előbb külön ellenőrizni kell a licenc kompatibilitását, az attribúciós
feltételeket, valamint azt, hogy a repositoryban található stock-derived adatok
egyáltalán továbbengedélyezhetők-e. Addig clean-room marad az egyetlen elfogadott
út.

