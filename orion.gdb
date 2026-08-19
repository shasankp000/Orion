# orion.gdb
#
# Custom GDB session script for Orion Kernel development.
#
# Usage:
#   Terminal 1: qemu-system-x86_64 -cdrom orion_v0.1.1.iso -s -S
#   Terminal 2: gdb -x orion.gdb orion_v0.1.1.elf
#
# This does three things automatically on load:
#   1. Connects to the QEMU GDB stub on localhost:1234
#   2. Loads a Python helper command: `orion-dump`
#   3. Sets a starting breakpoint at _start
#
# It does NOT auto-continue - you stay in control of stepping.

# ---------------------------------------------------------------------
# 1. Connect to QEMU
# ---------------------------------------------------------------------
target remote localhost:1234

# ---------------------------------------------------------------------
# 2. Quality-of-life GDB settings
# ---------------------------------------------------------------------
set pagination off
set disassembly-flavor intel

# ---------------------------------------------------------------------
# 3. Breakpoints
# ---------------------------------------------------------------------
break _start

# Add more breakpoints here as your kernel grows, e.g.:
# break sys_exit
# break no_response

# ---------------------------------------------------------------------
# 4. Load the Python helper (register + .bss dump command)
# ---------------------------------------------------------------------
source orion_dump.py

echo \n--- orion.gdb loaded ---\n
echo Type 'orion-dump' at any breakpoint to see all tracked registers and .bss variables.\n
echo Type 'orion-dump regs' or 'orion-dump bss' to see just one group.\n
echo Type 'orion-dump-pixels' AFTER sys_print_ASCII_character_green has run to\n
echo see an actual '#'/'.' grid of what got written to the framebuffer -\n
echo this is ground truth, independent of QEMU zoom/screenshot issues.\n
echo   orion-dump-pixels          -> 8 rows x 20 cols (roughly one character)\n
echo   orion-dump-pixels 8 160    -> 8 rows x 160 cols (the whole string)\n
echo ---\n
