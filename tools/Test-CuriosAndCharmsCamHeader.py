#!/usr/bin/env python3
"""Validate Curios UI, world states and custom construction lifecycle."""

import struct
import sys
from importlib import import_module
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
cam = import_module("Inspect-MajestyCam")
builder = import_module("Build-CuriosAndCharmsCam")

data = Path(sys.argv[1]).read_bytes()
source = Path(sys.argv[2]).read_bytes()
_major, _minor, sections = cam.parse_sections(data)
offsets = {section.name: section.directory_offset for section in sections}
_source_major, _source_minor, source_sections = cam.parse_sections(source)
source_offsets = {
    section.name: section.directory_offset for section in source_sections
}
source_tile_count = struct.unpack_from(
    "<I", source, source_offsets["TILE"]
)[0]
profile_tile_id = source_tile_count
icon_tile_id = source_tile_count + 1
preview_tile_id = source_tile_count + 2
finished_tile_id = source_tile_count + 3
construction_tile_ids = tuple(range(source_tile_count + 4, source_tile_count + 10))
build_phase_tile_ids = tuple(range(source_tile_count + 10, source_tile_count + 12))

tiles = cam.parse_tile(data, offsets["TILE"])
if [entry["tile_id"] for entry in tiles] != list(range(source_tile_count + 12)):
    raise SystemExit(
        "building TILE table is not padded through its twelve appended slots"
    )
stock_fervus = builder.raw_imag(source, builder.FERVUS_IMAG_NAME)
source_tiles = cam.parse_tile(source, source_offsets["TILE"])
expected_stock_tiles = {
    tile_id
    for tile_id in builder.referenced_tile_indices(stock_fervus, source_tile_count)
    if source_tiles[tile_id]["size"]
}
actual_stock_tiles = {
    tile_id for tile_id in range(source_tile_count) if tiles[tile_id]["size"]
}
if actual_stock_tiles != expected_stock_tiles:
    raise SystemExit("CAM does not retain exactly the Fervus-reachable stock TILEs")

for tile_id, expected_size, expected_palette in (
    (profile_tile_id, builder.PROFILE_SIZE, builder.PROFILE_PALETTE_ID),
    (icon_tile_id, builder.BUILD_LIST_ICON_SIZE, builder.BUILD_ICON_PALETTE_ID),
):
    header = struct.unpack_from("<13H", data, tiles[tile_id]["offset"])
    if not (
        tiles[tile_id]["size"]
        and header[0] == 1
        and (header[2], header[1]) == expected_size
        and header[3] == expected_size[0]
        and header[4] == 32
        and header[8] == 255
        and header[11] == expected_palette
    ):
        raise SystemExit(f"building UI TILE {tile_id} is invalid")

for tile_id in (
    preview_tile_id,
    finished_tile_id,
    *construction_tile_ids,
    *build_phase_tile_ids,
):
    world_header = struct.unpack_from("<13H", data, tiles[tile_id]["offset"])
    if not (
        tiles[tile_id]["size"]
        and world_header[0] == 3
        and world_header[1] > 0
        and world_header[2] > 0
        and world_header[11] == builder.BUILDING_SPRITE_PALETTE_ID
    ):
        raise SystemExit(f"world TILE {tile_id} is not a valid type-3 sprite")

palettes = cam.parse_splt(data, offsets["SPLT"])
if [entry["palette_id"] for entry in palettes] != list(range(len(palettes))):
    raise SystemExit("building palette table is not contiguous")
nonempty_palettes = {
    entry["palette_id"] for entry in palettes if entry["size"]
}
expected_palettes = {
    struct.unpack_from("<I", data, tiles[tile_id]["offset"] + 22)[0]
    for tile_id in actual_stock_tiles
    | {profile_tile_id, icon_tile_id, preview_tile_id, finished_tile_id}
    | set(construction_tile_ids)
    | set(build_phase_tile_ids)
    if tiles[tile_id]["size"] >= 26
}
expected_palettes = {
    palette_id for palette_id in expected_palettes if palette_id < len(palettes)
}
if nonempty_palettes != expected_palettes:
    raise SystemExit("CAM does not retain exactly the palettes used by its TILEs")
if any(palettes[index]["size"] != 1032 for index in nonempty_palettes):
    raise SystemExit("generated palette payload has an unexpected size")

imag = cam.parse_imag(data, offsets["IMAG"])[0]
payload = data[imag["offset"] : imag["offset"] + imag["size"]]
if struct.unpack_from("<I", payload, 20)[0] != 43:
    raise SystemExit("building IMAG is not the complete Fervus lifecycle")
low_words = [
    struct.unpack_from("<I", payload, cursor)[0] & 0xFFFF
    for cursor in range(0, len(payload) - 3, 4)
]
if low_words.count(profile_tile_id) != 1:
    raise SystemExit("building IMAG does not reference the appended profile exactly once")
if low_words.count(icon_tile_id) != 1:
    raise SystemExit("building IMAG does not reference the appended icon exactly once")
if low_words.count(preview_tile_id) != 1:
    raise SystemExit("building IMAG does not reference the custom preview exactly once")
if low_words.count(finished_tile_id) != 5:
    raise SystemExit("building IMAG does not reference all custom finished-state frames")
if any(low_words.count(tile_id) != 1 for tile_id in construction_tile_ids):
    raise SystemExit("building IMAG does not reference each custom construction frame once")
if any(tile_id in low_words for tile_id in builder.FERVUS_CONSTRUCTION_TILE_IDS):
    raise SystemExit("building IMAG still references a stock Fervus construction frame")
if any(low_words.count(tile_id) != 1 for tile_id in build_phase_tile_ids):
    raise SystemExit("building IMAG does not reference each custom build phase once")
if any(source_tile in low_words for _action_id, source_tile in builder.FERVUS_BUILD_PHASE_ACTIONS):
    raise SystemExit("building IMAG still references a stock Fervus build phase")
if builder.STOCK_BUILDING_PROFILE_TILE_ID in low_words:
    raise SystemExit("building IMAG still references the stock profile TILE")
if builder.STOCK_BUILD_LIST_ICON_TILE_ID in low_words:
    raise SystemExit("building IMAG still references the stock build-list icon TILE")

action_count = struct.unpack_from("<I", payload, 20)[0]
actions = {
    struct.unpack_from("<II", payload, 24 + index * 8)[0]:
    struct.unpack_from("<II", payload, 24 + index * 8)[1]
    for index in range(action_count)
}
if struct.unpack_from("<I", payload, actions[builder.FERVUS_NORMAL_ACTION_ID] + 112)[0] != preview_tile_id:
    raise SystemExit("building preview action does not point at the custom preview TILE")
if struct.unpack_from("<I", payload, actions[builder.FERVUS_ACTIVE_ACTION_ID] + 112)[0] != finished_tile_id:
    raise SystemExit("building Active action does not point at the custom finished TILE")
construction_offset = actions[builder.FERVUS_CONSTRUCTION_ACTION_ID]
actual_construction_tiles = tuple(
    struct.unpack_from("<I", payload, construction_offset + relative)[0]
    for relative in (96, 104, 112, 120, 128, 136)
)
if actual_construction_tiles != construction_tile_ids:
    raise SystemExit("building construction action does not use the six custom stages")
for (action_id, _source_tile), target_tile in zip(
    builder.FERVUS_BUILD_PHASE_ACTIONS, build_phase_tile_ids
):
    if struct.unpack_from("<I", payload, actions[action_id] + 112)[0] != target_tile:
        raise SystemExit(f"building phase action {action_id:#x} is not custom")
