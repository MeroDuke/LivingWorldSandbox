# Majesty CAM format — clean-room observations

These notes record measurements made exclusively from the read-only CAM file
shipped with the local Majesty SDK. They are not a complete format
specification until a generated archive has been loaded by the game.

## Verified container structure

- Magic: eight bytes, `CYLBPC  `.
- Version: two little-endian `u16` values. The SDK example is `1.1`.
- Section count: little-endian `u32` at offset `0x0c`.
- Unknown directory-related boundary: little-endian `u32` at offset `0x10`.
  It is 44 bytes before the first payload in the SDK sample, so it must not be
  labelled or regenerated as the payload start yet.
- Section directory: starts at `0x14`; every record is a four-character name
  followed by a little-endian directory offset.
- The official example contains `IMAG`, `TILE`, and `SPLT` sections.

The repository's read-only inspector validates every referenced payload against
the archive boundary:

```powershell
python tools/Inspect-MajestyCam.py `
  Sdk/Example/Data/WrathOfKrolm_maindata.cam --summary
```

## Verified section directories

### `IMAG`

- `u32` entry count;
- one additional `u32` directory marker;
- 28-byte records: 20-byte zero-terminated ASCII name, payload offset, payload
  size.

### `TILE`

- `u32` entry count;
- one additional `u32` directory marker;
- 28-byte records: numeric tile/frame ID, 16-byte zero-terminated ASCII family
  name, payload offset, payload size.

### `SPLT`

- `u32` entry count;
- one additional `u32` directory marker;
- 28-byte records: palette ID, 16 currently-zero bytes, payload offset, payload
  size.

## Decoded payload structure

- Every inspected `SPLT` payload is 1032 bytes: an eight-byte header
  (`0x01000000`, `0` as little-endian `u32` values) followed by
  256 RGBA-like four-byte colour entries. The first three components are red,
  green and blue; the fourth is reserved. Transparency is
  represented spatially by absent TILE runs, not by painting a palette entry.
- A type-3 `TILE` payload has a 26-byte fixed header followed by one `u32` offset
  per image row. Offsets are relative to byte 26.
- Each row contains runs encoded as `u16 x_end`, `u8 count`, `u8 flags`, then
  `count` palette indices. Flag `0x80` marks the final run in the row. A fully
  transparent row is represented by a zero-count final run.
- Header word 1 is image height and word 2 is image width. Palette index zero is
  reserved for transparency. Building art must also avoid the upper
  player-colour/control indices.
- Header word 11 selects the SPLT palette. The SDK building family uses palette
  9. CAM directories are position-addressed global tables: a custom archive
  using palette 9 must contain slots 0 through 9, although slots 0 through 8
  may be zero-length fallback entries. Omitting the required slot produces the
  engine error `Attempt to do 816 blit without a palette`. Directionless building TILEs also use observed layout
  flags `32` and `7` plus horizontal/bottom anchor values.
- `IMAG` appears to describe image-family metadata, not the world sprite pixels
  themselves. Runtime evidence also shows that TILE IDs are resolved in a
  merged/global namespace: custom TILE ID `0` displayed the base game's
  `DustofDeth` frame. Sparse (`50000`) and adjacent (`638`) references both
  resolved as transparent. The public Phantom's Haunt implementation supplies
  the missing rule: TILE references are global directory positions, and a CAM
  must contain every slot through its highest custom index. Unused earlier
  slots are zero-length entries that fall back to stock providers. A building IMAG
  begins with an action count and action ID/relative
  offset pairs. Its action blocks directly reference TILE IDs; the SDK altar
  family references IDs 603–637. Several other action fields remain unresolved.

`tools/Decode-MajestyCamTile.py` reproduces recognizable transparent PNGs from
the SDK sample. `tools/Test-MajestyCamTileDecoder.ps1` guards two independently
sized payloads.

## Writer status

The generated Curios and Charms archive has now rendered successfully in the
Northern Expansion runtime. The verified implementation recipe is maintained in
`Docs/custom-building-art-recipe.md`. Remaining unknowns concern additional
building states and UI art, not the basic type-3 world-sprite encoding.

## Isolated Curios and Charms experiment

`tools/Build-CuriosAndCharmsCam.py` builds a one-family experimental CAM from
the project-owned transparent PNG. It preserves the SDK altar IMAG references
603 through 637, pads the TILE directory through slot 637, places the visible
shop art in slots 603 through 606, and provides transparent project-owned
animation frames in slots 607 through 636. Earlier slots are zero-length
fallbacks. SPLT follows the same rule: slots 0 through 8 are empty and the
project palette occupies slot 9.

The first non-crashing in-game render exposed the TILE-ID collision above rather
than an encoder failure. Sparse experiments with `50000` and `638`, followed by
the public project's padding documentation, established that changing the IMAG
reference alone cannot bind a payload. The directory must be padded to the
referenced global position.

The isolated archive has been loaded by the game and the custom world sprite is
visible with correct geometry, transparency and colours. Extended lifecycle and
save/load regression remain pending.
