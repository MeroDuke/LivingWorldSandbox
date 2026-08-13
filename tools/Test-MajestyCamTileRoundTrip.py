#!/usr/bin/env python3
"""Exercise the clean-room TILE/SPLT encoder and decoder without game files."""

from __future__ import annotations

from importlib import import_module

from PIL import Image, ImageDraw

codec = import_module("Decode-MajestyCamTile")


def main() -> int:
    source = Image.new("RGBA", (19, 23), (0, 0, 0, 0))
    draw = ImageDraw.Draw(source)
    draw.rectangle((2, 3, 16, 19), fill=(120, 70, 30, 255))
    draw.rectangle((6, 0, 12, 8), fill=(220, 170, 40, 255))
    draw.rectangle((8, 9, 10, 14), fill=(0, 0, 0, 0))
    draw.point((0, 22), fill=(30, 150, 210, 255))

    palette = [(0, 0, 0, 255), (120, 70, 30, 255), (220, 170, 40, 255), (30, 150, 210, 255)]
    indices = Image.new("P", source.size, 0)
    mapping = {color[:3]: index for index, color in enumerate(palette) if index}
    for y in range(source.height):
        for x in range(source.width):
            pixel = source.getpixel((x, y))
            if pixel[3]:
                indices.putpixel((x, y), mapping[pixel[:3]])

    tile_payload = codec.encode_tile(source, indices)
    splt_payload = codec.encode_palette(palette)
    decoded_palette = codec.decode_palette(
        splt_payload, {"offset": 0, "size": len(splt_payload)}
    )
    decoded = codec.decode_tile(
        tile_payload, {"offset": 0, "size": len(tile_payload)}, decoded_palette
    )
    if decoded.size != source.size or decoded.tobytes() != source.tobytes():
        raise AssertionError("TILE/SPLT round trip changed pixels")
    print("Majesty CAM TILE/SPLT round-trip test passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
