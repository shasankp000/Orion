"""
orion_dump.py

A custom GDB command, `orion-dump`, for Orion Kernel debugging.

Instead of manually typing `x/gx &some_var` for every field every time
you hit a breakpoint, this reads a small config table (below) of every
.bss variable you care about - name + byte width - and prints them all
at once, correctly sized (no more accidentally reading 8 bytes of a
2-byte field and having to mentally mask it out).

USAGE (inside gdb, once this file is sourced):
    orion-dump          -> dumps both registers and .bss variables
    orion-dump regs     -> just the tracked registers
    orion-dump bss      -> just the tracked .bss variables

MAINTENANCE:
    Every time you add a new .bss variable in your .asm file, add one
    line to BSS_VARS below. That's the only place you need to touch.
"""

import gdb

# ---------------------------------------------------------------------
# Config: which registers to always show
# ---------------------------------------------------------------------
TRACKED_REGISTERS = [
    "rax", "rbx", "rcx", "rdx",
    "rsi", "rdi", "rbp", "rsp",
    "r8", "r8d", "r8b", "r9", "r10", "r11", "r12", "r13",
    "r14", "r15", "ax", "al", "bx", "bl", "dx", "dl",
    "cx", "cl", "di", "dil", "cs", "ds", "es", "ss"
]

# ---------------------------------------------------------------------
# Config: which .bss variables to track, and their byte width.
# Width must match your `resb N` declaration in the .asm file.
# Valid widths: 1, 2, 4, 8
# ---------------------------------------------------------------------
BSS_VARS = [
    ("bootloader_revision",              8),
    ("bootloader_name",                  8),
    ("bootloader_version",               8),
    ("framebuffer_revision",             8),
    ("framebuffer_count",                8),
    ("framebuffer_struct_address",       8),
    ("framebuffer_struct_width",         8),
    ("framebuffer_struct_height",        8),
    ("framebuffer_struct_pitch",         8),
    ("framebuffer_struct_bpp",           2),
    ("framebuffer_struct_red_mask_size",  1),
    ("framebuffer_struct_red_mask_shift", 1),
    ("framebuffer_struct_green_mask_size",  1),
    ("framebuffer_struct_green_mask_shift", 1),
    ("framebuffer_struct_blue_mask_size",  1),
    ("framebuffer_struct_blue_mask_shift", 1),
    ("pen_x", 8),
    ("pen_y", 8),
]


def read_memory_int(address, width):
    """Read `width` bytes at `address` and return as an unsigned int."""
    inferior = gdb.selected_inferior()
    raw = inferior.read_memory(address, width)
    return int.from_bytes(bytes(raw), byteorder="little", signed=False)


def format_register_row(name):
    try:
        val = int(gdb.parse_and_eval(f"${name}"))
        # registers can print negative in gdb's signed view; mask to unsigned 64-bit
        val &= 0xFFFFFFFFFFFFFFFF
        return f"  {name:<6} = 0x{val:016x}"
    except gdb.error as e:
        return f"  {name:<6} = <error: {e}>"


def format_bss_row(name, width):
    try:
        symbol_addr = int(gdb.parse_and_eval(f"&{name}"))
        val = read_memory_int(symbol_addr, width)
        hex_width = width * 2
        return f"  {name:<38} (@ 0x{symbol_addr:x}, {width}B) = 0x{val:0{hex_width}x}"
    except gdb.error as e:
        return f"  {name:<38} <error: {e}>"


class OrionDump(gdb.Command):
    """Dump tracked registers and/or .bss variables.

    Usage:
        orion-dump
        orion-dump regs
        orion-dump bss
    """

    def __init__(self):
        super(OrionDump, self).__init__("orion-dump", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        arg = arg.strip().lower()

        show_regs = arg in ("", "regs", "registers")
        show_bss = arg in ("", "bss")

        if not show_regs and not show_bss:
            print(f"Unknown argument '{arg}'. Use: orion-dump [regs|bss]")
            return

        if show_regs:
            print("-- registers --")
            for reg in TRACKED_REGISTERS:
                print(format_register_row(reg))

        if show_bss:
            if show_regs:
                print()
            print("-- .bss variables --")
            for name, width in BSS_VARS:
                print(format_bss_row(name, width))


# ---------------------------------------------------------------------
# orion-dump pixels: read raw framebuffer memory and render a text-art
# grid of which pixels are actually lit (green channel byte nonzero),
# starting at pen_x/pen_y. This answers "did my renderer actually draw
# this" far more reliably than a screenshot at any zoom level.
# ---------------------------------------------------------------------

def read_bss_value(name, width):
    addr = int(gdb.parse_and_eval(f"&{name}"))
    return read_memory_int(addr, width)


def dump_pixel_grid(rows, cols):
    """
    Read `rows` x `cols` pixels starting at (pen_x, pen_y) and print a
    grid: '#' where the green channel byte is nonzero, '.' otherwise.

    This mirrors plot_pixel's own address math exactly:
        offset = (y * pitch) + (x * bytes_per_pixel)
        pixel_address = framebuffer_struct_address + offset
    so what you see here is a direct read-back of whatever plot_pixel
    actually wrote, independent of any screen rendering/zoom issues.
    """
    fb_addr   = read_bss_value("framebuffer_struct_address", 8)
    pitch     = read_bss_value("framebuffer_struct_pitch", 8)
    bpp       = read_bss_value("framebuffer_struct_bpp", 2)
    green_shift = read_bss_value("framebuffer_struct_green_mask_shift", 1)
    pen_x     = read_bss_value("pen_x", 8)
    pen_y     = read_bss_value("pen_y", 8)

    bytes_per_pixel = bpp // 8
    green_byte_index = green_shift // 8  # which byte within the pixel holds the green channel

    print(f"-- pixel grid (rows={rows}, cols={cols}) --")
    print(f"  framebuffer_address = 0x{fb_addr:x}")
    print(f"  pitch = {pitch}, bpp = {bpp}, bytes_per_pixel = {bytes_per_pixel}")
    print(f"  green_mask_shift = {green_shift} (byte index {green_byte_index} within pixel)")
    print(f"  pen_x = {pen_x}, pen_y = {pen_y}")
    print()

    inferior = gdb.selected_inferior()
    lit_count = 0
    total = rows * cols

    for row in range(rows):
        line_chars = []
        for col in range(cols):
            x = pen_x + col
            y = pen_y + row
            offset = (y * pitch) + (x * bytes_per_pixel)
            pixel_addr = fb_addr + offset
            try:
                raw = inferior.read_memory(pixel_addr, bytes_per_pixel)
                pixel_bytes = bytes(raw)
                green_byte = pixel_bytes[green_byte_index]
            except (gdb.error, IndexError) as e:
                line_chars.append("?")
                continue

            if green_byte != 0:
                lit_count += 1
                line_chars.append("#")
            else:
                line_chars.append(".")

        print("  " + "".join(line_chars))

    print()
    print(f"  {lit_count} / {total} pixels lit")


class OrionDumpPixels(gdb.Command):
    """Read back raw framebuffer memory starting at (pen_x, pen_y) and
    print a text-art grid of lit/unlit pixels, based on the green channel.

    Usage:
        orion-dump-pixels                  -> 8 rows x 20 cols (one character-ish)
        orion-dump-pixels <rows> <cols>     -> custom grid size, e.g. 8 160 for the whole string
    """

    def __init__(self):
        super(OrionDumpPixels, self).__init__("orion-dump-pixels", gdb.COMMAND_USER)

    def invoke(self, arg, from_tty):
        args = arg.split()
        rows = int(args[0]) if len(args) >= 1 else 8
        cols = int(args[1]) if len(args) >= 2 else 20

        try:
            dump_pixel_grid(rows, cols)
        except gdb.error as e:
            print(f"Error reading framebuffer/pen state: {e}")
            print("Make sure you're stopped AFTER sys_query_framebuffer, "
                  "sys_get_center_of_screen, and (for a meaningful dump) "
                  "AFTER sys_print_ASCII_character_green has run.")


OrionDump()
OrionDumpPixels()
