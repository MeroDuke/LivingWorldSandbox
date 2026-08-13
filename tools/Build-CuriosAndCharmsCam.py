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
# Majesty resolves TILE and SPLT references by their global directory position.
# The Krolm altar layout uses frames 603..637 and palette 9, so the custom CAM
# must pad every preceding slot.  Empty entries fall back to the stock archives.
PALETTE_ID = 9
PALETTE_COUNT = PALETTE_ID + 1
FIRST_TILE_ID = 603
LAST_TILE_ID = 637
VISIBLE_TILE_IDS = range(603, 607)
TRANSPARENT_TILE_IDS = range(607, 637)
TILE_COUNT = LAST_TILE_ID + 1


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


def building_imag_template(sdk_cam: bytes) -> bytes:
    _major, _minor, sections = cam.parse_sections(sdk_cam)
    offsets = {section.name: section.directory_offset for section in sections}
    altar = next(
        entry
        for entry in cam.parse_imag(sdk_cam, offsets["IMAG"])
        if entry["name"] == "BB0tKrolm_Altar"
    )
    payload = sdk_cam[altar["offset"] : altar["offset"] + altar["size"]]
    if len(altar_frame_reference_offsets(sdk_cam)) != 121:
        raise ValueError("unexpected Krolm Altar frame-reference count")
    return payload


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
    palette_payload: bytes,
) -> bytes:
    header_size = 44
    imag_dir = header_size
    tile_dir = imag_dir + 8 + 28
    splt_dir = tile_dir + 8 + TILE_COUNT * 28
    payload_start = splt_dir + 8 + PALETTE_COUNT * 28
    imag_offset = payload_start
    tile_offsets: dict[int, int] = {}
    cursor = imag_offset + len(imag_payload)
    for tile_id in range(TILE_COUNT):
        payload = tile_payloads.get(tile_id, b"")
        if payload:
            tile_offsets[tile_id] = cursor
            cursor += len(payload)
    palette_offset = cursor

    result = bytearray(cam.MAGIC)
    # Offset 0x10 is relative to the end of the 44-byte container header.
    result.extend(struct.pack("<HHII", 1, 1, 3, payload_start - header_size))
    for name, offset in (("IMAG", imag_dir), ("TILE", tile_dir), ("SPLT", splt_dir)):
        result.extend(name.encode("ascii") + struct.pack("<I", offset))

    result.extend(struct.pack("<II", 1, 1))
    result.extend(fixed_ascii(IMAGE_ID + FAMILY, 20))
    result.extend(struct.pack("<II", imag_offset, len(imag_payload)))
    result.extend(struct.pack("<II", TILE_COUNT, 1))
    for tile_id in range(TILE_COUNT):
        payload = tile_payloads.get(tile_id, b"")
        result.extend(struct.pack("<I", tile_id) + fixed_ascii(FAMILY if payload else "", 16))
        result.extend(struct.pack("<II", tile_offsets.get(tile_id, 0), len(payload)))
    result.extend(struct.pack("<II", PALETTE_COUNT, 1))
    for palette_id in range(PALETTE_COUNT):
        payload = palette_payload if palette_id == PALETTE_ID else b""
        result.extend(struct.pack("<I", palette_id) + bytes(16))
        result.extend(struct.pack("<II", palette_offset if payload else 0, len(payload)))
    result.extend(imag_payload)
    for tile_id in range(TILE_COUNT):
        result.extend(tile_payloads.get(tile_id, b""))
    result.extend(palette_payload)
    return bytes(result)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_png", type=Path)
    parser.add_argument("sdk_example_cam", type=Path)
    parser.add_argument("output_cam", type=Path)
    args = parser.parse_args()

    source = Image.open(args.source_png).convert("RGBA")
    indices, colors = make_indexed(source)
    visible_tile = codec.encode_tile(source, indices, palette_id=PALETTE_ID, building_layout=True)
    transparent_source = Image.new("RGBA", (1, 1), (0, 0, 0, 0))
    transparent_indices = Image.new("P", (1, 1), 0)
    transparent_tile = codec.encode_tile(
        transparent_source, transparent_indices, palette_id=PALETTE_ID, building_layout=True
    )
    tile_payloads = {tile_id: visible_tile for tile_id in VISIBLE_TILE_IDS}
    tile_payloads.update({tile_id: transparent_tile for tile_id in TRANSPARENT_TILE_IDS})
    palette = codec.encode_palette(colors)
    imag = building_imag_template(args.sdk_example_cam.read_bytes())
    archive = build_archive(imag, tile_payloads, palette)
    args.output_cam.parent.mkdir(parents=True, exist_ok=True)
    args.output_cam.write_bytes(archive)
    print(
        f"Built isolated {IMAGE_ID} CAM: {args.output_cam} "
        f"({source.width}x{source.height}, {len(colors)} colours, {len(archive)} bytes)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
