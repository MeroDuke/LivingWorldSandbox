#!/usr/bin/env python3
"""Read-only structural inspector for Majesty CYLBPC CAM archives.

This tool intentionally does not extract payloads or write CAM files.  Its first
job is to make the locally shipped SDK example measurable and to fail closed on
unknown or out-of-bounds structures before an LWS archive writer is attempted.
"""

from __future__ import annotations

import argparse
import json
import struct
from dataclasses import dataclass
from pathlib import Path


MAGIC = b"CYLBPC  "
DIRECTORY_ENTRY_SIZE = 8


@dataclass(frozen=True)
class Section:
    name: str
    directory_offset: int


def u32(data: bytes, offset: int) -> int:
    if offset < 0 or offset + 4 > len(data):
        raise ValueError(f"u32 outside archive at offset {offset}")
    return struct.unpack_from("<I", data, offset)[0]


def ascii_name(raw: bytes) -> str:
    return raw.split(b"\0", 1)[0].decode("ascii", errors="strict")


def parse_sections(data: bytes) -> tuple[int, int, list[Section]]:
    if len(data) < 24 or data[:8] != MAGIC:
        raise ValueError("not a CYLBPC CAM archive")
    version_major, version_minor = struct.unpack_from("<HH", data, 8)
    count = u32(data, 12)
    # Offset 0x10 is the beginning of the section-directory area.  The
    # directory entries themselves begin at 0x14 in the official SDK sample.
    directory_area_offset = u32(data, 16)
    start = 20
    end = start + count * DIRECTORY_ENTRY_SIZE
    if count == 0 or end > len(data):
        raise ValueError("invalid CAM section directory")
    if directory_area_offset < end or directory_area_offset >= len(data):
        raise ValueError("invalid CAM directory-area boundary")

    sections: list[Section] = []
    for index in range(count):
        cursor = start + index * DIRECTORY_ENTRY_SIZE
        name = data[cursor : cursor + 4].decode("ascii", errors="strict")
        directory_offset = u32(data, cursor + 4)
        if directory_offset < end or directory_offset >= len(data):
            raise ValueError(f"section {name} has invalid directory offset")
        sections.append(Section(name, directory_offset))
    return version_major, version_minor, sections


def parse_imag(data: bytes, offset: int) -> list[dict[str, int | str]]:
    count = u32(data, offset)
    record_size = 28
    # IMAG has one reserved u32 after its entry count in the SDK sample.
    start = offset + 8
    end = start + count * record_size
    if end > len(data):
        raise ValueError("IMAG directory exceeds archive")
    result = []
    for index in range(count):
        cursor = start + index * record_size
        name = ascii_name(data[cursor : cursor + 20])
        payload_offset = u32(data, cursor + 20)
        payload_size = u32(data, cursor + 24)
        validate_payload(data, "IMAG", index, payload_offset, payload_size)
        result.append(
            {
                "index": index,
                "name": name,
                "offset": payload_offset,
                "size": payload_size,
            }
        )
    return result


def parse_tile(data: bytes, offset: int) -> list[dict[str, int | str]]:
    count = u32(data, offset)
    record_size = 28
    # TILE has a u32 directory marker (1 in the official SDK sample) after
    # its entry count; records then use zero-based tile/frame identifiers.
    directory_marker = u32(data, offset + 4)
    start = offset + 8
    end = start + count * record_size
    if end > len(data):
        raise ValueError("TILE directory exceeds archive")
    result = []
    for index in range(count):
        cursor = start + index * record_size
        tile_id = u32(data, cursor)
        name = ascii_name(data[cursor + 4 : cursor + 20])
        payload_offset = u32(data, cursor + 20)
        payload_size = u32(data, cursor + 24)
        validate_payload(data, "TILE", index, payload_offset, payload_size)
        result.append(
            {
                "index": index,
                "directory_marker": directory_marker,
                "tile_id": tile_id,
                "name": name,
                "offset": payload_offset,
                "size": payload_size,
            }
        )
    return result


def parse_splt(data: bytes, offset: int) -> list[dict[str, int]]:
    count = u32(data, offset)
    record_size = 28
    directory_marker = u32(data, offset + 4)
    start = offset + 8
    end = start + count * record_size
    if end > len(data):
        raise ValueError("SPLT directory exceeds archive")
    result = []
    for index in range(count):
        cursor = start + index * record_size
        palette_id = u32(data, cursor)
        reserved = data[cursor + 4 : cursor + 20]
        if any(reserved):
            raise ValueError(f"SPLT record {index} has unknown nonzero header bytes")
        payload_offset = u32(data, cursor + 20)
        payload_size = u32(data, cursor + 24)
        validate_payload(data, "SPLT", index, payload_offset, payload_size)
        result.append(
            {
                "index": index,
                "directory_marker": directory_marker,
                "palette_id": palette_id,
                "offset": payload_offset,
                "size": payload_size,
            }
        )
    return result


def validate_payload(
    data: bytes, section: str, index: int, payload_offset: int, payload_size: int
) -> None:
    if payload_offset > len(data) or payload_size > len(data) - payload_offset:
        raise ValueError(f"{section} payload {index} exceeds archive")


def inspect(path: Path) -> dict[str, object]:
    data = path.read_bytes()
    major, minor, sections = parse_sections(data)
    known = {"IMAG": parse_imag, "TILE": parse_tile, "SPLT": parse_splt}
    parsed: dict[str, object] = {}
    for section in sections:
        parser = known.get(section.name)
        if parser is None:
            raise ValueError(f"unsupported CAM section {section.name}")
        entries = parser(data, section.directory_offset)
        parsed[section.name] = {
            "directory_offset": section.directory_offset,
            "entry_count": len(entries),
            "entries": entries,
        }
    return {
        "path": str(path),
        "size": len(data),
        "version": f"{major}.{minor}",
        "sections": parsed,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("cam", type=Path)
    parser.add_argument("--summary", action="store_true")
    args = parser.parse_args()
    report = inspect(args.cam)
    if args.summary:
        report = {
            "path": report["path"],
            "size": report["size"],
            "version": report["version"],
            "sections": {
                name: {
                    "directory_offset": value["directory_offset"],
                    "entry_count": value["entry_count"],
                }
                for name, value in report["sections"].items()
            },
        }
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
