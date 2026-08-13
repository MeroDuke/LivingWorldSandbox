#!/usr/bin/env python3
"""Losslessly repack a supported Majesty CAM archive.

This clean-room tool rebuilds container and section directories while treating
IMAG/TILE/SPLT payloads as opaque bytes. It is intentionally not a custom asset
writer yet.
"""

from __future__ import annotations

import argparse
import struct
import sys
from importlib import import_module
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
cam = import_module("Inspect-MajestyCam")


def fixed_ascii(value: str, size: int) -> bytes:
    encoded = value.encode("ascii")
    if len(encoded) >= size:
        raise ValueError(f"ASCII value is too long for {size}-byte field: {value}")
    return encoded + bytes(size - len(encoded))


def align(value: int, boundary: int = 4) -> int:
    return (value + boundary - 1) // boundary * boundary


def repack(source: bytes) -> bytes:
    major, minor, sections = cam.parse_sections(source)
    section_map = {section.name: section for section in sections}
    if [section.name for section in sections] != ["IMAG", "TILE", "SPLT"]:
        raise ValueError("unsupported CAM section order")

    entries = {
        "IMAG": cam.parse_imag(source, section_map["IMAG"].directory_offset),
        "TILE": cam.parse_tile(source, section_map["TILE"].directory_offset),
        "SPLT": cam.parse_splt(source, section_map["SPLT"].directory_offset),
    }
    markers = {
        name: cam.u32(source, section_map[name].directory_offset + 4)
        for name in entries
    }

    header_size = 20 + len(sections) * 8
    directory_offsets: dict[str, int] = {}
    cursor = header_size
    record_sizes = {"IMAG": 28, "TILE": 28, "SPLT": 28}
    for section in sections:
        directory_offsets[section.name] = cursor
        cursor += 8 + len(entries[section.name]) * record_sizes[section.name]
    payload_start = align(cursor)

    payload_offsets: dict[tuple[str, int], int] = {}
    cursor = payload_start
    for section in sections:
        for entry in entries[section.name]:
            payload_offsets[(section.name, entry["index"])] = cursor
            cursor += entry["size"]

    result = bytearray()
    result.extend(cam.MAGIC)
    # The value at 0x10 is not the first payload offset (the SDK sample differs
    # by 44 bytes). Preserve it until its exact semantics are proven.
    result.extend(
        struct.pack("<HHII", major, minor, len(sections), cam.u32(source, 16))
    )
    for section in sections:
        result.extend(section.name.encode("ascii"))
        result.extend(struct.pack("<I", directory_offsets[section.name]))

    for section in sections:
        name = section.name
        result.extend(struct.pack("<II", len(entries[name]), markers[name]))
        for entry in entries[name]:
            payload_offset = payload_offsets[(name, entry["index"])]
            if name == "IMAG":
                result.extend(fixed_ascii(str(entry["name"]), 20))
            elif name == "TILE":
                result.extend(struct.pack("<I", entry["tile_id"]))
                result.extend(fixed_ascii(str(entry["name"]), 16))
            else:
                result.extend(struct.pack("<I", entry["palette_id"]))
                result.extend(bytes(16))
            result.extend(struct.pack("<II", payload_offset, entry["size"]))

    result.extend(bytes(payload_start - len(result)))
    for section in sections:
        for entry in entries[section.name]:
            start = entry["offset"]
            result.extend(source[start : start + entry["size"]])
    return bytes(result)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    rebuilt = repack(args.source.read_bytes())
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_bytes(rebuilt)
    print(f"Repacked {args.source} -> {args.output} ({len(rebuilt)} bytes)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
