#!/usr/bin/env python3
"""Extract AGI v2 LOGIC messages into a translation skeleton.

This tool only reads a player-supplied AGI directory.  It never rewrites
VOL/LOGDIR resources.  The LOGIC message area uses the historical cyclic
XOR key ``Avis Durgan``; the decoded English is used as the runtime key.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path

KEY = b"Avis Durgan"


def file_case_insensitive(root: Path, name: str) -> Path:
    for p in root.iterdir():
        if p.name.lower() == name.lower():
            return p
    raise FileNotFoundError(name)


def read_logdir(root: Path):
    data = file_case_insensitive(root, "LOGDIR").read_bytes()
    for i in range(0, len(data) - 2, 3):
        b0, b1, b2 = data[i:i + 3]
        if (b0, b1, b2) == (0xff, 0xff, 0xff):
            yield None
        else:
            yield (b0 >> 4, ((b0 & 0x0f) << 16) | (b1 << 8) | b2)


def read_resource(root: Path, entry):
    if entry is None:
        return None
    vol, offset = entry
    path = file_case_insensitive(root, f"VOL.{vol}")
    with path.open("rb") as f:
        f.seek(offset)
        header = f.read(5)
        if len(header) != 5 or header[:2] != b"\x12\x34":
            return None
        size = header[3] | (header[4] << 8)
        return f.read(size)


def messages(logic: bytes):
    if len(logic) < 2:
        return []
    code_size = int.from_bytes(logic[:2], "little")
    pos = 2 + code_size
    if pos + 3 > len(logic):
        return []
    count = logic[pos]
    section_size = int.from_bytes(logic[pos + 1:pos + 3], "little")
    offsets = pos + 3
    strings = offsets + 2 * count
    encrypted_size = section_size - 2 - 2 * count
    decoded = bytearray(logic)
    for i in range(max(0, encrypted_size)):
        if strings + i < len(decoded):
            decoded[strings + i] ^= KEY[i % len(KEY)]
    result = []
    for index in range(count):
        off = offsets + index * 2
        rel = int.from_bytes(logic[off:off + 2], "little")
        if rel == 0:
            continue
        start = pos + 1 + rel
        end = decoded.find(0, start)
        if end < 0:
            end = len(decoded)
        text = bytes(decoded[start:end]).decode("latin1", "replace")
        if text:
            result.append(text)
    return result


def tsv_key(text: str) -> str:
    return text.replace("\\", "\\\\").replace("\t", "\\t").replace("\r", "\\r").replace("\n", "\\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("game_dir", type=Path)
    ap.add_argument("output", type=Path)
    args = ap.parse_args()
    seen, rows = set(), []
    for entry in read_logdir(args.game_dir):
        for text in messages(read_resource(args.game_dir, entry) or b""):
            if not text.strip():
                continue
            key = tsv_key(text)
            if key not in seen:
                seen.add(key)
                rows.append(f"{key}\t{key}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(rows) + "\n", encoding="utf-8")
    print(f"AGI LOGIC: {len(rows)} unique messages -> {args.output}")


if __name__ == "__main__":
    main()
