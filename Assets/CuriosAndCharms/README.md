# Curios and Charms art workspace

Ez a könyvtár a saját készítésű Curios and Charms épületgrafikák munkaterülete.

## Jelenlegi állapot

- `concept/curios-and-charms-l1-concept.png`: jóváhagyott nagyfelbontású L1
  látványterv.
- `source/curios-and-charms-l1-chromakey.png`: egyszerűsített, egyszínű hátterű
  forrás a technikai sprite-próbához.
- `preview/curios-and-charms-l1-192.png`: átlátszó, 192 px magas előnézet.
- `preview/curios-and-charms-l1-192-v2.png`: Majesty-kompatibilisebb izometrikus
  nézet, a korábbi runtime sprite-nál körülbelül 18%-kal kisebb vizuális
  footprinttel.
- `preview/curios-and-charms-l1-192-v3.png`: további 12–15 fokkal magasabb
  kameraállású változat; ez a jelenlegi PoC runtime-forrás.
- `preview/curios-and-charms-l1-256.png`: átlátszó, 256 px magas előnézet.

Az `preview/curios-and-charms-l1-192.png` már a bizonyított runtime CAM/TILE
pipeline forrása. Az árnyék, footprint és további épületállapotok még
finomhangolásra szorulnak.

## Izolált CAM PoC

A `tools/Build-CuriosAndCharmsCam.py` már képes a 192 px-es előnézetből saját
palettás TILE-t és kísérleti building IMAG-ot tartalmazó CAM-ot készíteni. A
visszafejtett sprite és a játékon belüli render vizuálisan helyes. A reprodukálható
formátumleírás a `Docs/custom-building-art-recipe.md` fájlban található.

## Eredet

A képek a projekthez generált, eredeti AI-koncepciók. Nem tartalmaznak külső
modból vagy stock Majesty CAM-ból másolt grafikát.
