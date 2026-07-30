#!/usr/bin/env python3
"""Extract names from an AGI OBJECT file into a translation skeleton.

AGI 2.x stores a table of 3-byte entries followed by NUL-terminated names.
Older DOS releases encrypt the whole file with the same cyclic ``Avis Durgan``
XOR used by LOGIC messages.  This tool only reads the supplied game directory.
"""
from __future__ import annotations

import argparse
from pathlib import Path

KEY = b"Avis Durgan"


def find_file(root: Path, name: str) -> Path:
    for p in root.iterdir():
        if p.name.lower() == name.lower():
            return p
    raise FileNotFoundError(name)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("game_dir", type=Path)
    ap.add_argument("output", type=Path)
    args = ap.parse_args()

    data = bytearray(find_file(args.game_dir, "OBJECT").read_bytes())
    if len(data) < 3:
        raise SystemExit("OBJECT is too short")
    if int.from_bytes(data[:2], "little") > len(data):
        for i in range(len(data)):
            data[i] ^= KEY[i % len(KEY)]

    pad = 3
    count = int.from_bytes(data[:2], "little") // pad
    # PQ1 is AGI 2.0; its name offsets are relative to the table start + 3.
    base = 3
    rows, seen = [], set()
    for index in range(count):
        pos = base + index * pad
        if pos + 3 > len(data):
            break
        offset = int.from_bytes(data[pos:pos + 2], "little") + base
        if offset >= len(data):
            continue
        end = data.find(0, offset)
        if end < 0:
            end = len(data)
        raw = bytes(data[offset:end])
        try:
            text = raw.decode("latin1")
        except UnicodeDecodeError:
            continue
        if not text or text in seen:
            continue
        seen.add(text)
        key = text.replace("\\", "\\\\").replace("\t", "\\t").replace("\n", "\\n")
        rows.append(f"{key}\t{key}")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text("\n".join(rows) + "\n", encoding="utf-8")
    print(f"AGI OBJECT: {len(rows)} unique names -> {args.output}")


if __name__ == "__main__":
    main()
