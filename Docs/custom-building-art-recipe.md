# Custom Majesty building art recipe

Ez a dokumentum a Curios and Charms 2026-08-13-i sikeres játéktesztje alapján
rögzíti a reprodukálható world-sprite pipeline-t. A recept a Northern Expansion
runtime-ban bizonyított; más engine-változatot külön kell ellenőrizni.

## Bizonyított eredmény

A saját, átlátszó PNG-ből készített épület:

- külön CAM providerből betöltődik;
- a teljes sprite-ot helyes geometriával rajzolja ki;
- megtartja az eredeti RGB-színeket;
- átlátszó hátteret használ;
- kijelölhető, HP-val rendelkező buildingként működik.

## Forrásgrafika

- RGBA PNG, valódi alpha csatornával.
- A jelenlegi bizonyított méret `175 x 192` pixel.
- A háttér teljesen átlátszó; nem chromakey-szín.
- A motor számára az átlátszóságot a hiányzó TILE-runok jelentik.

## CAM container

Szükséges sectionök:

1. `IMAG` – building action/frame layout;
2. `TILE` – indexelt sprite képkockák;
3. `SPLT` – 256 színű paletta.

A Curios and Charms PoC a read-only SDK Krolm Altar IMAG-struktúráját használja
sablonként. Az eredeti `603..637` frame-hivatkozásokat meg kell tartani.

### Globális slot-padding

A `TILE` és `SPLT` hivatkozás CAM-directory pozíció. Ha a legmagasabb használt
TILE a `637`, akkor a directorynak `638` rekordot kell tartalmaznia.

- `TILE 0..602`: zero-length fallback rekord;
- `TILE 603..606`: saját látható building sprite;
- `TILE 607..636`: saját átlátszó animációs frame;
- `TILE 637`: jelenleg zero-length fallback; a végleges profil/ikon külön munka.

A Krolm-layout palettája a `9`-es slot:

- `SPLT 0..8`: zero-length fallback rekord;
- `SPLT 9`: saját 1032 byte-os paletta.

Egy magas ID-jű rekord önmagában nem elég: minden korábbi directory-pozíciót
létre kell hozni.

## Type-3 TILE formátum

A fixed header 26 byte. Az első releváns `u16` mezők:

| Index | Jelentés a bizonyított encoderben |
|---:|---|
| 0 | type = `3` |
| 1 | image height |
| 2 | image width |
| 3 | width copy/layout value |
| 4 | building flags = `32` |
| 5 | horizontal anchor |
| 6 | vertical/bottom anchor |
| 7 | building/player-colour mode = `7` |
| 11 | SPLT palette slot = `9` |

A 26 byte-os header után `height` darab `u32` sor-offset következik. Az offsetek
a 26. byte-hoz viszonyítottak.

Minden sor runjai:

```text
u16 x_end
u8  pixel_count
u8  flags
u8[pixel_count] palette_indices
```

- `x_start = x_end - pixel_count`;
- egy run legfeljebb 80 pixeles;
- az utolsó run `flags & 0x80` jelölést kap;
- teljesen átlátszó sor: `x_end=0, count=0, flags=0x80`.

Fontos: ez soralapú formátum. Az oszlopalapú kódolás részleges, széthúzott
épületdarabokat eredményezett.

## Paletta

Az SPLT payload:

- 8 byte header: little-endian `0x01000000`, majd `0`;
- 256 darab nég byte-os `R, G, B, reserved` rekord.

Az index `0` átlátszósági sentinel, ezért látható pixel nem használhatja.
A building player-colour feldolgozása miatt a felső vezérlő/index-tartományba
sem teszünk normál képszínt. A jelenlegi encoder:

- legfeljebb 240 látható színt kvantál;
- ezeket az `1..240` indexekre teszi;
- a `0` indexet és a felső tartományt szabadon hagyja.

A BGR sorrend hibás kékes/csíkos renderelést okozott; a bizonyított sorrend RGB.

## Build és ellenőrzés

```powershell
python tools/Test-MajestyCamTileRoundTrip.py
powershell -ExecutionPolicy Bypass -File tools/Test-CuriosAndCharmsCam.ps1
powershell -ExecutionPolicy Bypass -File tools/Build-CombatDiagnostic.ps1
powershell -ExecutionPolicy Bypass -File tools/Test-CombatDiagnostic.ps1
powershell -ExecutionPolicy Bypass -File tools/New-QuestPackages.ps1
```

A másolható tesztcsomag:

```text
output/LWSCombatDiagnostic
```

## Hibajelenségek gyors értelmezése

| Tünet | Valószínű ok |
|---|---|
| `Attempt to do 816 blit without a palette` | hiányzik a hivatkozott SPLT directory slot |
| stock rom vagy idegen sprite | rossz globális TILE-slot / hiányos padding |
| teljesen láthatatlan épület | nem létező frame-slot vagy hibás/üres payload |
| részleges, széthúzott kép | felcserélt width/height vagy oszlopos run-kódolás |
| kékes, csíkos, elszínezett kép | BGR/RGB tévedés vagy player-colour indexek használata |
| helyes kép, hibás pozíció | anchor/footprint finomhangolás szükséges |

## Még nem végleges

- construction, damaged és destroyed állapotok saját képkészlete;
- aktív animációk;
- building profile és build-menu ikon;
- árnyék és footprint végleges illesztése;
- L2/L3 grafika;
- save/load és több egymást követő runtime-start regresszió.

