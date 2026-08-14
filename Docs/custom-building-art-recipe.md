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

## Build-menu icon and Palace dependency

The Palace icon is not an independent image hook. It is part of the complete
buildable-building IMAG lifecycle. `ABQ1Temple, Fervus1` contains 43 actions,
including placement, construction, damage, destruction, profile and the
`0x3EA` Palace build-list action. The Krolm altar contains only 14 actions, so
adding the icon action to it produced an incomplete and unstable hybrid.

The verified Phantom-style diagnostic therefore works in this order:

1. clone the complete Fervus level-1 IMAG;
2. retain the stock payload of every TILE reachable from that IMAG; an empty
   record in this custom building provider renders as a transparent frame and
   does not reliably fall back to the identically numbered stock TILE;
3. append the custom profile and build-list icon after the installed global
   TILE table (currently slots 17224 and 17225);
4. remap only the original Fervus profile/icon references 1509/1510 to those
   appended slots;
5. retain every palette used by the reachable stock frames, then preserve each
   stock type-1 UI TILE header and quantize against its actual stock UI palette.
6. once that baseline is stable, replace the finished states in isolation: the
   placement preview uses action `0x50` / TILE 1502; the completed building's
   shared visual is TILE 1505; action `0xC0` / TILE 1506 is its separate active
   variant. Preview and completed states use separate appended custom TILEs so
   each preserves the correct stock hotspot.
7. replace the six construction frames only after placement and completion are
   proven stable. Fervus action `0x10000C0` references TILEs 1511-1516 at action
   offsets 96, 104, 112, 120, 128 and 136. Curios appends six bottom-up reveal
   stages and remaps exactly those references; leaving them stock is why the
   building temporarily turned into the Fervus temple while peasants worked.
8. the engine also visits actions `0x51` / TILE 1503 and `0x52` / TILE 1504
   during construction. They are separate base phases, not members of the
   six-frame construction animation. Both must receive their own appended
   Curios reveal TILE; otherwise two brief Fervus transformations remain even
   after all six animation frames have been replaced.

The stock profile is 100x100 and uses SPLT 102. The stock Palace list icon is
25x25 and uses SPLT 103. Palette 560 belongs to the Fervus world sprites, not
these UI frames; using it for the icon caused the earlier incorrect colours.

Custom world art is introduced one lifecycle group at a time. The finished
Curios image is encoded with the Phantom native-size type-3 row-RLE recipe,
quantized against Fervus world palette 560, horizontally centred and
bottom-aligned using the corresponding stock hotspot. Construction uses six
separately encoded progressive reveal frames with the same recipe. Damage and
ruin remain stock until they are replaced separately. Replacing all Fervus
references with one finished-building TILE destroys placement and build states
and can crash when BUILD is pressed.

Building text has three distinct roles: `Name` is the internal prototype title,
`Description` is the visible building name, and `HelpID` points to the long
flavour/help string. Putting prose or a string key in `Description` renames the
unit everywhere, including the Palace build list.

Build availability is provided through `DATA/BDEP`. Because Majesty replaces
that payload as a whole, `Build-CuriosAndCharmsBdep.py` reads the installed
`Data/miscdata.cam`, preserves every stock rule, and appends only:

```text
LC01 : ABJ1 ABJ2 NOT NOT ABJ3 NOT NOT || ||
```

This is the stock Marketplace Palace-1-or-better expression with the custom
building ID. The generated provider is diagnostic output and is never copied
from the read-only SDK into source control.
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
