#!/usr/bin/env python3
"""Decode one indexed TILE payload from a Majesty CAM archive to PNG.

The decoder is clean-room tooling derived from measurements of the read-only
SDK example. It never modifies its CAM input.
"""

from __future__ import annotations

import argparse
import struct
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from importlib import import_module

cam = import_module("Inspect-MajestyCam")


def decode_palette(data: bytes, entry: dict[str, int]) -> list[tuple[int, int, int, int]]:
    offset = entry["offset"]
    if entry["size"] != 1032:
        raise ValueError("unsupported SPLT payload")
    version_marker, reserved = struct.unpack_from("<II", data, offset)
    if version_marker != 0x01000000 or reserved != 0:
        raise ValueError("unsupported SPLT payload header")
    count = 256
    colors = []
    for index in range(count):
        red, green, blue, _reserved = struct.unpack_from("<BBBB", data, offset + 8 + index * 4)
        colors.append((red, green, blue, 255))
    return colors


def encode_palette(colors: list[tuple[int, int, int, int]]) -> bytes:
    if len(colors) > 256:
        raise ValueError("SPLT supports at most 256 colours")
    result = bytearray(struct.pack("<II", 0x01000000, 0))
    padded = colors + [(0, 0, 0, 255)] * (256 - len(colors))
    for red, green, blue, _alpha in padded:
        result.extend(struct.pack("<BBBB", red, green, blue, 0))
    return bytes(result)


def encode_tile(
    image: Image.Image,
    palette_indices: Image.Image,
    palette_id: int = 0,
    building_layout: bool = False,
) -> bytes:
    image = image.convert("RGBA")
    if palette_indices.mode != "P" or palette_indices.size != image.size:
        raise ValueError("palette index image must be mode P and match RGBA input")
    width, height = image.size
    if width == 0 or width > 0xFFFF or height == 0 or height > 0xFFFF:
        raise ValueError("unsupported TILE dimensions")

    rows: list[bytes] = []
    alpha = image.getchannel("A")
    for y in range(height):
        encoded = bytearray()
        x = 0
        while x < width:
            if alpha.getpixel((x, y)) == 0:
                x += 1
                continue
            start = x
            indices = bytearray()
            while x < width and alpha.getpixel((x, y)) != 0 and len(indices) < 80:
                indices.append(palette_indices.getpixel((x, y)))
                x += 1
            next_x = x
            while next_x < width and alpha.getpixel((next_x, y)) == 0:
                next_x += 1
            flags = 0 if next_x < width else 0x80
            encoded.extend(struct.pack("<HBB", start + len(indices), len(indices), flags))
            encoded.extend(indices)
        if not encoded:
            encoded.extend(struct.pack("<HBB", 0, 0, 0x80))
        rows.append(bytes(encoded))

    if not 0 <= palette_id <= 0xFFFF:
        raise ValueError("palette ID must fit u16")
    if building_layout:
        # Structural values observed on the SDK's directionless building TILE:
        # format flags 32, centered horizontal anchor, bottom vertical anchor,
        # 7-bit/player-colour mode, and an explicit SPLT palette ID.
        fixed_header = struct.pack(
            "<13H", 3, height, width, width, 32, width // 2, height - 1,
            7, 0, 0, 0, palette_id, 0
        )
    else:
        fixed_header = struct.pack("<13H", 3, height, width, width, 0, 0, 0, 0, 0, 0, 0, palette_id, 0)
    table_size = height * 4
    offsets = []
    cursor = table_size
    for row in rows:
        offsets.append(cursor)
        cursor += len(row)
    return fixed_header + struct.pack(f"<{height}I", *offsets) + b"".join(rows)


def decode_tile(data: bytes, entry: dict[str, int], palette: list[tuple[int, int, int, int]]) -> Image.Image:
    offset = entry["offset"]
    size = entry["size"]
    payload = data[offset : offset + size]
    tile_type, height, width, _width_copy = struct.unpack_from("<4H", payload, 0)
    if tile_type != 3:
        raise ValueError("unsupported TILE payload header")

    # The fixed header is 26 bytes. The following height u32 values are row
    # offsets relative to byte 26.
    table_base = 26
    row_offsets = struct.unpack_from(f"<{height}I", payload, table_base)
    if row_offsets[0] != height * 4:
        raise ValueError("unexpected TILE row-table boundary")

    image = Image.new("RGBA", (width, height), (0, 0, 0, 0))
    pixels = image.load()
    for y, relative in enumerate(row_offsets):
        cursor = table_base + relative
        row_end = (
            table_base + row_offsets[y + 1]
            if y + 1 < height
            else len(payload)
        )
        while cursor < row_end:
            if cursor + 4 > row_end:
                raise ValueError(f"truncated TILE run header in row {y}")
            x_end, count, flags = struct.unpack_from("<HBB", payload, cursor)
            cursor += 4
            if count == 0:
                if flags & 0x80:
                    break
                raise ValueError(f"invalid empty TILE run in row {y}")
            if cursor + count > row_end or x_end < count or x_end > width:
                raise ValueError(f"invalid TILE run in row {y}")
            indices = payload[cursor : cursor + count]
            cursor += count
            for x, palette_index in enumerate(indices, start=x_end - count):
                pixels[x, y] = palette[palette_index]
            if flags & 0x80:
                break
    return image


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cam", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--tile-index", type=int, default=0)
    parser.add_argument("--palette-index", type=int, default=0)
    args = parser.parse_args()

    data = args.cam.read_bytes()
    _major, _minor, sections = cam.parse_sections(data)
    offsets = {section.name: section.directory_offset for section in sections}
    tiles = cam.parse_tile(data, offsets["TILE"])
    palettes = cam.parse_splt(data, offsets["SPLT"])
    tile = tiles[args.tile_index]
    palette = decode_palette(data, palettes[args.palette_index])
    image = decode_tile(data, tile, palette)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.output)
    print(f"Decoded {tile['name']} #{tile['tile_id']} -> {args.output} ({image.width}x{image.height})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
