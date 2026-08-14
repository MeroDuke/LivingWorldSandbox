#!/usr/bin/env python3
"""Build an isolated Curios and Charms CAM proof-of-concept.

The image and palette are project-owned. The building IMAG action layout is a
clean-room structural derivation from the read-only SDK example and is kept
isolated from runtime configuration until an explicit in-game test.
"""

from __future__ import annotations

import argparse
import struct
import sys
from importlib import import_module
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
codec = import_module("Decode-MajestyCamTile")
cam = import_module("Inspect-MajestyCam")


IMAGE_ID = "BCc1"
FAMILY = "CuriosCharms"
# The complete Fervus lifecycle stays stock in this first diagnostic. Empty
# TILE records fall back to maindata.cam; only its two UI frames are appended.
PROFILE_PALETTE_ID = 102
BUILD_ICON_PALETTE_ID = 103
STOCK_BUILDING_PROFILE_TILE_ID = 1509
STOCK_BUILD_LIST_ICON_TILE_ID = 1510
PROFILE_SIZE = (100, 100)
BUILD_LIST_ICON_SIZE = (25, 25)
FERVUS_IMAG_NAME = b"ABQ1Temple, Fervus1"
FERVUS_NORMAL_ACTION_ID = 0x50
FERVUS_NORMAL_TILE_ID = 1502
FERVUS_BUILD_PHASE_ACTIONS = ((0x51, 1503), (0x52, 1504))
FERVUS_FINISHED_TILE_ID = 1505
FERVUS_ACTIVE_ACTION_ID = 0xC0
FERVUS_ACTIVE_TILE_ID = 1506
FERVUS_CONSTRUCTION_ACTION_ID = 0x10000C0
FERVUS_CONSTRUCTION_TILE_IDS = tuple(range(1511, 1517))
BUILDING_SPRITE_PALETTE_ID = 560


def fixed_ascii(value: str, size: int) -> bytes:
    encoded = value.encode("ascii")
    if len(encoded) >= size:
        raise ValueError(f"{value!r} does not fit a {size}-byte CAM name")
    return encoded + bytes(size - len(encoded))


def make_indexed(source: Image.Image) -> tuple[Image.Image, list[tuple[int, int, int, int]]]:
    rgba = source.convert("RGBA")
    opaque = Image.new("RGB", rgba.size, (0, 0, 0))
    opaque.paste(rgba.convert("RGB"), mask=rgba.getchannel("A"))
    # Keep Majesty's high player-colour/control range unused.  The building
    # layout enables player-colour processing, so ordinary artwork in those
    # indices is recoloured by the engine.
    quantized = opaque.quantize(colors=240, method=Image.Quantize.MEDIANCUT)
    raw_palette = quantized.getpalette() or []
    # Palette index zero is the TILE transparency sentinel.
    colors = [(0, 0, 0, 255)]
    used = sorted(set(quantized.getdata()))
    remap = {old: new + 1 for new, old in enumerate(used)}
    indices = Image.new("P", rgba.size, 0)
    for old in used:
        base = old * 3
        colors.append((raw_palette[base], raw_palette[base + 1], raw_palette[base + 2], 255))
    indices.putdata([remap[value] for value in quantized.getdata()])
    return indices, colors


def encode_type1_ui_tile(
    source: Image.Image,
    palette_indices: Image.Image,
    palette_id: int,
) -> bytes:
    """Encode the raw type-1 form used by stock building profile/list art."""
    source = source.convert("RGBA")
    if palette_indices.mode != "P" or palette_indices.size != source.size:
        raise ValueError("palette index image must match UI source")
    width, height = source.size
    transparent_index = 255
    pixels = bytearray()
    alpha = source.getchannel("A")
    for y in range(height):
        for x in range(width):
            pixels.append(
                palette_indices.getpixel((x, y))
                if alpha.getpixel((x, y)) != 0
                else transparent_index
            )
    # Matches the stock maindata 1509/1510 type-1 layout: raw row-major
    # indices, building flag 32, transparency sentinel 255 and SPLT slot.
    header = struct.pack(
        "<13H",
        1,
        height,
        width,
        width,
        32,
        0,
        0,
        0,
        transparent_index,
        0,
        0,
        palette_id,
        0,
    )
    return header + pixels


def raw_imag(source_cam: bytes, wanted_name: bytes) -> bytes:
    _major, _minor, sections = cam.parse_sections(source_cam)
    offsets = {section.name: section.directory_offset for section in sections}
    directory = offsets["IMAG"]
    count = struct.unpack_from("<I", source_cam, directory)[0]
    payload = None
    for index in range(count):
        cursor = directory + 8 + index * 28
        raw_name = source_cam[cursor : cursor + 20].split(b"\0", 1)[0]
        if raw_name != wanted_name:
            continue
        payload_offset, payload_size = struct.unpack_from("<II", source_cam, cursor + 20)
        payload = source_cam[payload_offset : payload_offset + payload_size]
        break
    if payload is None:
        raise ValueError(f"{wanted_name!r} IMAG was not found")
    return payload


def raw_indexed_entry(source_cam: bytes, section_name: str, index: int) -> bytes:
    _major, _minor, sections = cam.parse_sections(source_cam)
    offsets = {section.name: section.directory_offset for section in sections}
    parser = cam.parse_tile if section_name == "TILE" else cam.parse_splt
    entries = parser(source_cam, offsets[section_name])
    entry = entries[index]
    return source_cam[entry["offset"] : entry["offset"] + entry["size"]]


def ui_tile_from_stock_template(
    source: Image.Image,
    stock_tile: bytes,
    stock_palette: bytes,
    expected_size: tuple[int, int],
    palette_id: int,
) -> bytes:
    """Replace pixels while retaining the stock type-1 UI TILE contract."""
    tile_type, height, width, row_stride = struct.unpack_from("<4H", stock_tile, 0)
    if tile_type != 1 or (width, height) != expected_size or row_stride != width:
        raise ValueError("stock building UI TILE has an unexpected layout")
    if len(stock_palette) != 1032:
        raise ValueError("stock building UI palette has an unexpected layout")
    colors = [
        struct.unpack_from("<BBBB", stock_palette, 8 + index * 4)[:3]
        for index in range(256)
    ]
    rgba = source.convert("RGBA")
    output = bytearray(stock_tile[:26])
    struct.pack_into("<I", output, 22, palette_id)
    alpha = rgba.getchannel("A")
    for y in range(height):
        for x in range(width):
            if alpha.getpixel((x, y)) == 0:
                output.append(255)
                continue
            red, green, blue, _a = rgba.getpixel((x, y))
            # 255 is the stock transparency sentinel and must not be selected.
            output.append(
                min(
                    range(255),
                    key=lambda index: (
                        (colors[index][0] - red) ** 2
                        + (colors[index][1] - green) ** 2
                        + (colors[index][2] - blue) ** 2
                    ),
                )
            )
    image_plane_size = row_stride * height
    if len(stock_tile) > 26 + image_plane_size:
        output.extend(stock_tile[26 + image_plane_size :])
    return bytes(output)


def nearest_visible_palette_index(
    red: int,
    green: int,
    blue: int,
    colors: list[tuple[int, int, int]],
) -> int:
    """Match Phantom's visible-pixel palette selection rules."""
    candidates = (
        index
        for index, (palette_red, palette_green, palette_blue) in enumerate(colors)
        if index not in (0, 255)
        and not (palette_red > 115 and palette_green < 80 and palette_blue > 115)
        and not (
            index >= 247
            and palette_green < 80
            and palette_red > 80
            and palette_blue > 80
        )
    )
    return min(
        candidates,
        key=lambda index: (
            (colors[index][0] - red) ** 2
            + (colors[index][1] - green) ** 2
            + (colors[index][2] - blue) ** 2
        ),
    )


def encode_indexed_v3_tile_like_original(
    original_tile: bytes,
    pixels: list[list[int]],
    *,
    split_shadow_controls: bool = False,
) -> bytes:
    """Encode the row-RLE type-3 form used by stock building sprites."""
    if len(original_tile) < 26 or struct.unpack_from("<H", original_tile, 0)[0] != 3:
        raise ValueError("stock building frame is not an indexed type-3 TILE")
    height = len(pixels)
    width = len(pixels[0]) if pixels else 0
    header = bytearray(original_tile[:26])
    struct.pack_into("<HHH", header, 2, height, width, width)
    rows: list[bytes] = []
    for row_pixels in pixels:
        row = bytearray()
        x = 0
        while x < len(row_pixels):
            if row_pixels[x] == 0:
                x += 1
                continue
            start = x
            values: list[int] = []
            segment_is_shadow = 247 <= row_pixels[x] <= 250
            while x < len(row_pixels) and row_pixels[x] != 0 and len(values) < 80:
                value_is_shadow = 247 <= row_pixels[x] <= 250
                if split_shadow_controls and values and value_is_shadow != segment_is_shadow:
                    break
                values.append(row_pixels[x])
                x += 1
            next_x = x
            while next_x < len(row_pixels) and row_pixels[next_x] == 0:
                next_x += 1
            row.extend(struct.pack("<HBB", start + len(values), len(values), 0 if next_x < len(row_pixels) else 0x80))
            row.extend(values)
        if not row:
            row.extend(struct.pack("<HBB", 0, 0, 0x80))
        rows.append(bytes(row))
    output = bytearray(header)
    cursor = height * 4
    for row in rows:
        output.extend(struct.pack("<I", cursor))
        cursor += len(row)
    for row in rows:
        output.extend(row)
    return bytes(output)


def world_tile_from_stock_template(
    source: Image.Image,
    stock_tile: bytes,
    stock_palette: bytes,
    palette_id: int,
) -> bytes:
    """Apply Phantom's native-size, bottom-centred building-frame recipe."""
    if len(stock_palette) != 1032:
        raise ValueError("stock building palette has an unexpected layout")
    colors = [
        struct.unpack_from("<BBBB", stock_palette, 8 + index * 4)[:3]
        for index in range(256)
    ]
    image = source.convert("RGBA")
    shadow_markers = {
        (156, 33, 24): 247,
        (178, 0, 178): 248,
        (204, 0, 204): 249,
        (229, 0, 229): 250,
    }
    pixels: list[list[int]] = []
    for y in range(image.height):
        row: list[int] = []
        for x in range(image.width):
            red, green, blue, alpha = image.getpixel((x, y))
            if alpha < 16 or (red < 10 and green < 10 and blue < 12):
                row.append(0)
            elif (red, green, blue) in shadow_markers:
                row.append(shadow_markers[(red, green, blue)])
            else:
                row.append(nearest_visible_palette_index(red, green, blue, colors))
        pixels.append(row)
    template = bytearray(stock_tile)
    struct.pack_into("<I", template, 22, palette_id)
    encoded = bytearray(
        encode_indexed_v3_tile_like_original(
            bytes(template), pixels, split_shadow_controls=True
        )
    )
    original_height, original_width = struct.unpack_from("<HH", stock_tile, 2)
    original_hotspot_x, original_hotspot_y = struct.unpack_from("<HH", stock_tile, 10)
    hotspot_x = int(original_hotspot_x + (image.width - original_width) / 2.0 + 0.5)
    hotspot_y = original_hotspot_y + image.height - original_height
    struct.pack_into(
        "<HH",
        encoded,
        10,
        max(0, min(0xFFFF, hotspot_x)),
        max(0, min(0xFFFF, hotspot_y)),
    )
    return bytes(encoded)


def construction_stage_source(source: Image.Image, completion: float) -> Image.Image:
    """Reveal the custom building from the ground up for one build phase."""
    if not 0.0 < completion <= 1.0:
        raise ValueError("construction completion must be within (0, 1]")
    image = source.convert("RGBA")
    alpha = image.getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise ValueError("custom building art has no visible pixels")
    _left, top, _right, bottom = bounds
    cutoff = bottom - max(1, round((bottom - top) * completion))
    staged_alpha = alpha.point(lambda value: value)
    pixels = staged_alpha.load()
    for y in range(top, cutoff):
        for x in range(image.width):
            pixels[x, y] = 0
    result = image.copy()
    result.putalpha(staged_alpha)
    return result


def remap_low16(payload: bytes, source: int, target: int) -> bytes:
    patched = bytearray(payload)
    count = 0
    for cursor in range(0, len(patched) - 3, 4):
        value = struct.unpack_from("<I", patched, cursor)[0]
        if value & 0xFFFF == source:
            struct.pack_into("<I", patched, cursor, (value & 0xFFFF0000) | target)
            count += 1
    if count != 1:
        raise ValueError(f"expected one low16 TILE {source}, found {count}")
    return bytes(patched)


def remap_all_low16(
    payload: bytes,
    source: int,
    target: int,
    expected_count: int,
) -> bytes:
    """Remap every occurrence of one measured building TILE reference."""
    patched = bytearray(payload)
    count = 0
    for cursor in range(0, len(patched) - 3, 4):
        value = struct.unpack_from("<I", patched, cursor)[0]
        if value & 0xFFFF == source:
            struct.pack_into("<I", patched, cursor, (value & 0xFFFF0000) | target)
            count += 1
    if count != expected_count:
        raise ValueError(
            f"expected {expected_count} low16 TILE {source} references, found {count}"
        )
    return bytes(patched)


def remap_building_action_frame(
    payload: bytes,
    action_id: int,
    expected_source_tile: int,
    target_tile: int,
) -> bytes:
    """Remap one stock building action frame without touching other states."""
    patched = bytearray(payload)
    action_count = struct.unpack_from("<I", payload, 20)[0]
    for index in range(action_count):
        entry = 24 + index * 8
        current_action, action_offset = struct.unpack_from("<II", payload, entry)
        if current_action != action_id:
            continue
        frame_offset = action_offset + 112
        source_tile = struct.unpack_from("<I", payload, frame_offset)[0]
        if source_tile != expected_source_tile:
            raise ValueError(
                f"action {action_id:#x} expected TILE {expected_source_tile}, found {source_tile}"
            )
        struct.pack_into("<I", patched, frame_offset, target_tile)
        return bytes(patched)
    raise ValueError(f"building action {action_id:#x} was not found")


def remap_animation_action_frames(
    payload: bytes,
    action_id: int,
    replacements: dict[int, int],
) -> bytes:
    """Remap the measured frame TILEs inside one multi-frame action."""
    patched = bytearray(payload)
    action_count = struct.unpack_from("<I", payload, 20)[0]
    actions = [
        struct.unpack_from("<II", payload, 24 + index * 8)
        for index in range(action_count)
    ]
    for index, (current_action, action_offset) in enumerate(actions):
        if current_action != action_id:
            continue
        action_end = actions[index + 1][1] if index + 1 < len(actions) else len(payload)
        counts = {source: 0 for source in replacements}
        for cursor in range(action_offset, action_end, 4):
            value = struct.unpack_from("<I", payload, cursor)[0]
            if value not in replacements:
                continue
            struct.pack_into("<I", patched, cursor, replacements[value])
            counts[value] += 1
        unexpected = {source: count for source, count in counts.items() if count != 1}
        if unexpected:
            raise ValueError(
                f"action {action_id:#x} construction frame counts are invalid: {unexpected}"
            )
        return bytes(patched)
    raise ValueError(f"building animation action {action_id:#x} was not found")


def referenced_tile_indices(imag: bytes, tile_count: int) -> set[int]:
    """Match the Phantom builder's conservative IMAG reachability scan."""
    direct = {
        struct.unpack_from("<I", imag, cursor)[0]
        for cursor in range(0, len(imag) - 3, 4)
        if struct.unpack_from("<I", imag, cursor)[0] < tile_count
    }
    low16 = {
        struct.unpack_from("<I", imag, cursor)[0] & 0xFFFF
        for cursor in range(0, len(imag) - 3, 4)
        if (struct.unpack_from("<I", imag, cursor)[0] & 0xFFFF) < tile_count
    }
    return direct | low16


def building_imag_template(
    source_cam: bytes,
    building_profile_tile_id: int,
    build_list_icon_tile_id: int,
    preview_tile_id: int,
    finished_tile_id: int,
    construction_tile_ids: tuple[int, ...],
    build_phase_tile_ids: tuple[int, ...],
) -> bytes:
    """Keep Fervus lifecycle structure and replace UI plus finished idle art."""
    fervus = raw_imag(source_cam, FERVUS_IMAG_NAME)
    fervus = remap_low16(
        fervus, STOCK_BUILDING_PROFILE_TILE_ID, building_profile_tile_id
    )
    fervus = remap_low16(
        fervus, STOCK_BUILD_LIST_ICON_TILE_ID, build_list_icon_tile_id
    )
    fervus = remap_building_action_frame(
        fervus,
        FERVUS_NORMAL_ACTION_ID,
        FERVUS_NORMAL_TILE_ID,
        preview_tile_id,
    )
    fervus = remap_building_action_frame(
        fervus,
        FERVUS_ACTIVE_ACTION_ID,
        FERVUS_ACTIVE_TILE_ID,
        finished_tile_id,
    )
    if len(build_phase_tile_ids) != len(FERVUS_BUILD_PHASE_ACTIONS):
        raise ValueError("custom build-phase TILE count does not match the stock lifecycle")
    for (action_id, source_tile_id), target_tile_id in zip(
        FERVUS_BUILD_PHASE_ACTIONS, build_phase_tile_ids
    ):
        fervus = remap_building_action_frame(
            fervus,
            action_id,
            source_tile_id,
            target_tile_id,
        )
    fervus = remap_all_low16(
        fervus,
        FERVUS_FINISHED_TILE_ID,
        finished_tile_id,
        expected_count=4,
    )
    if len(construction_tile_ids) != len(FERVUS_CONSTRUCTION_TILE_IDS):
        raise ValueError("custom construction TILE count does not match the stock lifecycle")
    return remap_animation_action_frames(
        fervus,
        FERVUS_CONSTRUCTION_ACTION_ID,
        dict(zip(FERVUS_CONSTRUCTION_TILE_IDS, construction_tile_ids)),
    )


def altar_frame_reference_offsets(sdk_cam: bytes) -> list[int]:
    """Return the measured frame-reference fields in the SDK altar IMAG."""
    _major, _minor, sections = cam.parse_sections(sdk_cam)
    offsets = {section.name: section.directory_offset for section in sections}
    altar = next(
        entry
        for entry in cam.parse_imag(sdk_cam, offsets["IMAG"])
        if entry["name"] == "BB0tKrolm_Altar"
    )
    payload = sdk_cam[altar["offset"] : altar["offset"] + altar["size"]]
    action_count = struct.unpack_from("<I", payload, 20)[0]
    actions = [struct.unpack_from("<II", payload, 24 + index * 8) for index in range(action_count)]
    result = []
    for index, (_action_id, relative) in enumerate(actions):
        end = actions[index + 1][1] if index + 1 < len(actions) else len(payload)
        result.extend(
            cursor
            for cursor in range(relative, end, 4)
            if 603 <= struct.unpack_from("<I", payload, cursor)[0] <= 637
        )
    return result


def build_archive(
    imag_payload: bytes,
    tile_payloads: dict[int, bytes],
    palette_payloads: dict[int, bytes],
    tile_count: int,
    palette_count: int,
) -> bytes:
    header_size = 44
    imag_dir = header_size
    tile_dir = imag_dir + 8 + 28
    splt_dir = tile_dir + 8 + tile_count * 28
    payload_start = splt_dir + 8 + palette_count * 28
    imag_offset = payload_start
    tile_offsets: dict[int, int] = {}
    cursor = imag_offset + len(imag_payload)
    for tile_id in range(tile_count):
        payload = tile_payloads.get(tile_id, b"")
        if payload:
            tile_offsets[tile_id] = cursor
            cursor += len(payload)
    palette_offsets: dict[int, int] = {}
    for palette_id in range(palette_count):
        payload = palette_payloads.get(palette_id, b"")
        if payload:
            palette_offsets[palette_id] = cursor
            cursor += len(payload)

    result = bytearray(cam.MAGIC)
    # Offset 0x10 is relative to the end of the 44-byte container header.
    result.extend(struct.pack("<HHII", 1, 1, 3, payload_start - header_size))
    for name, offset in (("IMAG", imag_dir), ("TILE", tile_dir), ("SPLT", splt_dir)):
        result.extend(name.encode("ascii") + struct.pack("<I", offset))

    result.extend(struct.pack("<II", 1, 1))
    result.extend(fixed_ascii(IMAGE_ID + FAMILY, 20))
    result.extend(struct.pack("<II", imag_offset, len(imag_payload)))
    result.extend(struct.pack("<II", tile_count, 1))
    for tile_id in range(tile_count):
        payload = tile_payloads.get(tile_id, b"")
        result.extend(struct.pack("<I", tile_id) + fixed_ascii(FAMILY if payload else "", 16))
        result.extend(struct.pack("<II", tile_offsets.get(tile_id, 0), len(payload)))
    result.extend(struct.pack("<II", palette_count, 1))
    for palette_id in range(palette_count):
        payload = palette_payloads.get(palette_id, b"")
        result.extend(struct.pack("<I", palette_id) + bytes(16))
        result.extend(struct.pack("<II", palette_offsets.get(palette_id, 0), len(payload)))
    result.extend(imag_payload)
    for tile_id in range(tile_count):
        result.extend(tile_payloads.get(tile_id, b""))
    for palette_id in range(palette_count):
        result.extend(palette_payloads.get(palette_id, b""))
    return bytes(result)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_png", type=Path)
    parser.add_argument("build_icon_png", type=Path)
    parser.add_argument("sdk_example_cam", type=Path)
    parser.add_argument("source_maindata_cam", type=Path)
    parser.add_argument("output_cam", type=Path)
    args = parser.parse_args()

    source = Image.open(args.source_png).convert("RGBA")
    icon_source = Image.open(args.build_icon_png).convert("RGBA")
    icon_source.thumbnail(BUILD_LIST_ICON_SIZE, Image.Resampling.LANCZOS)
    icon_canvas = Image.new("RGBA", BUILD_LIST_ICON_SIZE, (0, 0, 0, 0))
    icon_canvas.alpha_composite(
        icon_source,
        ((BUILD_LIST_ICON_SIZE[0] - icon_source.width) // 2,
         (BUILD_LIST_ICON_SIZE[1] - icon_source.height) // 2),
    )
    icon_source = icon_canvas
    source_maindata = args.source_maindata_cam.read_bytes()
    _major, _minor, source_sections = cam.parse_sections(source_maindata)
    source_offsets = {
        section.name: section.directory_offset for section in source_sections
    }
    source_tile_count = struct.unpack_from(
        "<I", source_maindata, source_offsets["TILE"]
    )[0]
    source_palette_count = struct.unpack_from(
        "<I", source_maindata, source_offsets["SPLT"]
    )[0]
    building_profile_tile_id = source_tile_count
    build_list_icon_tile_id = source_tile_count + 1
    preview_tile_id = source_tile_count + 2
    finished_tile_id = source_tile_count + 3
    construction_tile_ids = tuple(
        range(source_tile_count + 4, source_tile_count + 10)
    )
    build_phase_tile_ids = tuple(
        range(source_tile_count + 10, source_tile_count + 12)
    )
    tile_count = source_tile_count + 12

    source_tiles = cam.parse_tile(source_maindata, source_offsets["TILE"])
    source_palettes = cam.parse_splt(source_maindata, source_offsets["SPLT"])
    stock_fervus = raw_imag(source_maindata, FERVUS_IMAG_NAME)
    reachable_tiles = referenced_tile_indices(stock_fervus, source_tile_count)
    tile_payloads = {
        tile_id: source_maindata[
            source_tiles[tile_id]["offset"] :
            source_tiles[tile_id]["offset"] + source_tiles[tile_id]["size"]
        ]
        for tile_id in reachable_tiles
        if source_tiles[tile_id]["size"]
    }
    reachable_palettes = set()
    for tile in tile_payloads.values():
        if len(tile) < 26:
            continue
        palette_id = struct.unpack_from("<I", tile, 22)[0]
        if palette_id < source_palette_count:
            reachable_palettes.add(palette_id)

    stock_profile_tile = raw_indexed_entry(
        source_maindata, "TILE", STOCK_BUILDING_PROFILE_TILE_ID
    )
    stock_icon_tile = raw_indexed_entry(
        source_maindata, "TILE", STOCK_BUILD_LIST_ICON_TILE_ID
    )
    stock_preview_tile = raw_indexed_entry(
        source_maindata, "TILE", FERVUS_NORMAL_TILE_ID
    )
    stock_finished_tile = raw_indexed_entry(
        source_maindata, "TILE", FERVUS_FINISHED_TILE_ID
    )
    stock_construction_tiles = tuple(
        raw_indexed_entry(source_maindata, "TILE", tile_id)
        for tile_id in FERVUS_CONSTRUCTION_TILE_IDS
    )
    stock_build_phase_tiles = tuple(
        raw_indexed_entry(source_maindata, "TILE", tile_id)
        for _action_id, tile_id in FERVUS_BUILD_PHASE_ACTIONS
    )
    stock_profile_palette = raw_indexed_entry(
        source_maindata, "SPLT", PROFILE_PALETTE_ID
    )
    stock_icon_palette = raw_indexed_entry(
        source_maindata, "SPLT", BUILD_ICON_PALETTE_ID
    )
    stock_world_palette = raw_indexed_entry(
        source_maindata, "SPLT", BUILDING_SPRITE_PALETTE_ID
    )
    icon_tile = ui_tile_from_stock_template(
        icon_source,
        stock_icon_tile,
        stock_icon_palette,
        BUILD_LIST_ICON_SIZE,
        BUILD_ICON_PALETTE_ID,
    )
    profile_source = source.copy()
    profile_source.thumbnail(PROFILE_SIZE, Image.Resampling.LANCZOS)
    profile_canvas = Image.new("RGBA", PROFILE_SIZE, (0, 0, 0, 0))
    profile_canvas.alpha_composite(
        profile_source,
        ((PROFILE_SIZE[0] - profile_source.width) // 2,
         (PROFILE_SIZE[1] - profile_source.height) // 2),
    )
    profile_tile = ui_tile_from_stock_template(
        profile_canvas,
        stock_profile_tile,
        stock_profile_palette,
        PROFILE_SIZE,
        PROFILE_PALETTE_ID,
    )
    preview_tile = world_tile_from_stock_template(
        source,
        stock_preview_tile,
        stock_world_palette,
        BUILDING_SPRITE_PALETTE_ID,
    )
    finished_tile = world_tile_from_stock_template(
        source,
        stock_finished_tile,
        stock_world_palette,
        BUILDING_SPRITE_PALETTE_ID,
    )
    construction_tiles = tuple(
        world_tile_from_stock_template(
            construction_stage_source(source, completion),
            stock_tile,
            stock_world_palette,
            BUILDING_SPRITE_PALETTE_ID,
        )
        for completion, stock_tile in zip(
            (0.18, 0.32, 0.48, 0.64, 0.82, 1.0),
            stock_construction_tiles,
        )
    )
    build_phase_tiles = tuple(
        world_tile_from_stock_template(
            construction_stage_source(source, completion),
            stock_tile,
            stock_world_palette,
            BUILDING_SPRITE_PALETTE_ID,
        )
        for completion, stock_tile in zip(
            (0.42, 0.76),
            stock_build_phase_tiles,
        )
    )
    tile_payloads.update({
        building_profile_tile_id: profile_tile,
        build_list_icon_tile_id: icon_tile,
        preview_tile_id: preview_tile,
        finished_tile_id: finished_tile,
        **dict(zip(construction_tile_ids, construction_tiles)),
        **dict(zip(build_phase_tile_ids, build_phase_tiles)),
    })
    reachable_palettes.update(
        {PROFILE_PALETTE_ID, BUILD_ICON_PALETTE_ID, BUILDING_SPRITE_PALETTE_ID}
    )
    palettes = {
        palette_id: source_maindata[
            source_palettes[palette_id]["offset"] :
            source_palettes[palette_id]["offset"]
            + source_palettes[palette_id]["size"]
        ]
        for palette_id in reachable_palettes
        if source_palettes[palette_id]["size"]
    }
    imag = building_imag_template(
        source_maindata,
        building_profile_tile_id,
        build_list_icon_tile_id,
        preview_tile_id,
        finished_tile_id,
        construction_tile_ids,
        build_phase_tile_ids,
    )
    palette_count = max(palettes) + 1
    archive = build_archive(
        imag, tile_payloads, palettes, tile_count, palette_count
    )
    args.output_cam.parent.mkdir(parents=True, exist_ok=True)
    args.output_cam.write_bytes(archive)
    print(
        f"Built isolated {IMAGE_ID} CAM: {args.output_cam} "
        f"(stock Fervus lifecycle, UI tiles {building_profile_tile_id}/"
        f"{build_list_icon_tile_id}, preview/finished TILEs "
        f"{preview_tile_id}/{finished_tile_id}, "
        f"construction TILEs {construction_tile_ids[0]}-"
        f"{construction_tile_ids[-1]}, "
        f"build-phase TILEs {build_phase_tile_ids[0]}-"
        f"{build_phase_tile_ids[-1]}, "
        f"{len(tile_payloads) - 12} stock frames, "
        f"{len(archive)} bytes)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
