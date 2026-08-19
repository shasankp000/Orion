#!/usr/bin/env python3
"""
gen_font_inc.py

Converts font8x8_basic.h (dhepper/font8x8, public domain) into a NASM
.inc file: one label + 8 `db` bytes per glyph, indexed 0x00-0x7F.

Usage:
    python3 gen_font_inc.py font8x8_basic.h font8x8_basic.inc

Output layout:
    font8x8_basic:
        db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  ; U+0000 (nul)
        ...
        db 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  ; U+007F

Because every glyph is a fixed 8 bytes, you index a character `c` at
runtime with:  font8x8_basic + (c * 8)
No per-glyph labels needed, no lookup table required - straight
multiply-and-offset, same spirit as your ABI offset tables.
"""

import re
import sys


def parse_font_header(path):
    """
    Pull out each `{ 0xNN, 0xNN, ..., 0xNN }` initializer row, in file
    order, along with its trailing `// U+XXXX (...)` comment if present.
    Returns a list of (hex_byte_list, comment) tuples.
    """
    with open(path, "r") as f:
        text = f.read()

    # Match a brace-enclosed byte list, optionally followed by a // comment
    # on the same line. Handles both `0x1E` and `0x1e` style hex.
    row_pattern = re.compile(
        r"\{\s*((?:0[xX][0-9a-fA-F]{1,2}\s*,\s*)*0[xX][0-9a-fA-F]{1,2})\s*\}"
        r"\s*,?\s*(?://\s*(.*))?"
    )

    rows = []
    for match in row_pattern.finditer(text):
        byte_list_raw, comment = match.groups()
        bytes_hex = [b.strip() for b in byte_list_raw.split(",")]
        rows.append((bytes_hex, comment.strip() if comment else ""))

    return rows


def write_nasm_inc(rows, out_path, label="font8x8_basic"):
    with open(out_path, "w") as f:
        f.write(f"; Auto-generated from font8x8_basic.h - do not edit by hand.\n")
        f.write(f"; Regenerate with: python3 gen_font_inc.py font8x8_basic.h {out_path}\n")
        f.write(f"; {len(rows)} glyphs, 8 bytes each, indexed 0x00-0x{len(rows)-1:02X}.\n")
        f.write(f"; Runtime lookup: {label} + (char_code * 8)\n\n")
        f.write(f"section .rodata\n\n")
        f.write(f"{label}:\n")
        for i, (byte_list, comment) in enumerate(rows):
            byte_str = ", ".join(byte_list)
            if comment:
                f.write(f"    db {byte_str}  ; {comment}\n")
            else:
                f.write(f"    db {byte_str}  ; index {i} (0x{i:02X})\n")
        f.write(f"\n{label}_end:\n")


def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <input .h file> <output .inc file>")
        sys.exit(1)

    in_path, out_path = sys.argv[1], sys.argv[2]

    rows = parse_font_header(in_path)
    if not rows:
        print("No glyph rows found - check the input file format.")
        sys.exit(1)

    write_nasm_inc(rows, out_path)
    print(f"Wrote {len(rows)} glyphs ({len(rows) * 8} bytes) to {out_path}")


if __name__ == "__main__":
    main()
