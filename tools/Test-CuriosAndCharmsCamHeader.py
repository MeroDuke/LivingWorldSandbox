#!/usr/bin/env python3
"""Validate engine-relevant Curios and Charms TILE/SPLT linkage."""

import struct
import sys
from importlib import import_module
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
cam = import_module("Inspect-MajestyCam")
builder = import_module("Build-CuriosAndCharmsCam")

data = Path(sys.argv[1]).read_bytes()
sdk_data = Path(sys.argv[2]).read_bytes()
_major, _minor, sections = cam.parse_sections(data)
offsets = {section.name: section.directory_offset for section in sections}
tiles = cam.parse_tile(data, offsets["TILE"])
if [entry["tile_id"] for entry in tiles] != list(range(builder.TILE_COUNT)):
    raise SystemExit("building TILE table is not padded through global slot 637")
if any(entry["size"] for entry in tiles[:builder.FIRST_TILE_ID]):
    raise SystemExit("fallback TILE slots before the custom building are not empty")
for tile_id in builder.VISIBLE_TILE_IDS:
    header = struct.unpack_from("<13H", data, tiles[tile_id]["offset"])
    if not (tiles[tile_id]["size"] and header[4] == 32 and header[7] == 7 and header[11] == builder.PALETTE_ID):
        raise SystemExit(f"visible building TILE {tile_id} is invalid")
palettes = cam.parse_splt(data, offsets["SPLT"])
if [entry["palette_id"] for entry in palettes] != list(range(builder.PALETTE_COUNT)):
    raise SystemExit("building palette table is not contiguous through slot 9")
if any(entry["size"] for entry in palettes[:builder.PALETTE_ID]) or palettes[builder.PALETTE_ID]["size"] != 1032:
    raise SystemExit("custom palette is not isolated in global slot 9")

imag = cam.parse_imag(data, offsets["IMAG"])[0]
payload = data[imag["offset"] : imag["offset"] + imag["size"]]
reference_offsets = builder.altar_frame_reference_offsets(sdk_data)
references = [struct.unpack_from("<I", payload, cursor)[0] for cursor in reference_offsets]
if len(reference_offsets) != 121 or min(references) != builder.FIRST_TILE_ID or max(references) != builder.LAST_TILE_ID:
    raise SystemExit("building IMAG no longer preserves the measured global frame references")
