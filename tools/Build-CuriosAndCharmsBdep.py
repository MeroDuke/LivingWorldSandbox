#!/usr/bin/env python3
"""Create the Curios and Charms BDEP provider from the installed game table."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path

MAGIC = b"CYLBPC  "
RULE = "LC01 : ABJ1 ABJ2 NOT NOT ABJ3 NOT NOT || ||"


def fixed_ascii(value: str, size: int) -> bytes:
    raw = value.encode("ascii")
    if len(raw) >= size:
        raise ValueError(f"{value!r} does not fit in {size} bytes")
    return raw + bytes(size - len(raw))


def read_bdep(source: bytes) -> bytes:
    if source[:8] != MAGIC:
        raise ValueError("not a Majesty CAM archive")
    section_count = struct.unpack_from("<I", source, 12)[0]
    data_offset = None
    for index in range(section_count):
        cursor = 20 + index * 8
        if source[cursor : cursor + 4] == b"DATA":
            data_offset = struct.unpack_from("<I", source, cursor + 4)[0]
            break
    if data_offset is None:
        raise ValueError("DATA section not found")
    count = struct.unpack_from("<I", source, data_offset)[0]
    for index in range(count):
        cursor = data_offset + 8 + index * 28
        name = source[cursor : cursor + 20].split(b"\0", 1)[0]
        if name == b"BDEP":
            offset, size = struct.unpack_from("<II", source, cursor + 20)
            return source[offset : offset + size]
    raise ValueError("DATA/BDEP payload not found")


def append_rule(payload: bytes) -> bytes:
    text = payload.decode("latin1").replace("\r\n", "\n").rstrip("\n")
    if RULE not in text.splitlines():
        text += "\n\n# Curios and Charms requires Palace level 1 or better\n" + RULE
    return (text + "\n\n").replace("\n", "\r\n").encode("latin1")


def build_cam(payload: bytes) -> bytes:
    directory_offset = 28
    payload_offset = directory_offset + 8 + 28
    result = bytearray(MAGIC)
    result.extend(struct.pack("<HHII", 1, 1, 1, payload_offset))
    result.extend(b"DATA" + struct.pack("<I", directory_offset))
    result.extend(struct.pack("<II", 1, 0))
    result.extend(fixed_ascii("BDEP", 20))
    result.extend(struct.pack("<II", payload_offset, len(payload)))
    result.extend(payload)
    return bytes(result)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("source_miscdata", type=Path)
    parser.add_argument("output_cam", type=Path)
    args = parser.parse_args()
    payload = append_rule(read_bdep(args.source_miscdata.read_bytes()))
    args.output_cam.parent.mkdir(parents=True, exist_ok=True)
    args.output_cam.write_bytes(build_cam(payload))
    print(f"Built Curios and Charms BDEP provider: {args.output_cam}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
