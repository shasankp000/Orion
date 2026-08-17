# Orion
An x86-64 kernel, built for the Limine bootloader.

The motivation behind this project is because I am simply tired of both Windows AND Linux

# Project Status

I just started building this after learning some basic x86-64 assembly lol.

# Calling conventions

```
RAX = syscall number
RBX = arg 1
RCX = arg 2
RDX = arg 3
RSI = arg 4
RDI = arg 5
R8  = permission register // my goal is to have certain syscalls restricted and cannot be accessible from userspace.
RSP = stack // Provided by Limine, stays as is.

// remaining registers are free, safe, un-clobbered
```

Note: argument registers are not always used sequentially in the order listed above. Future syscalls
will try to stick to `RBX -> RCX -> RDX -> RSI -> RDI` in order as much as possible, but this isn't a hard
rule -- in some cases a later register gets used ahead of an earlier one (see syscall 4 below for why).

The kernel currently has 6 syscalls, wired into a syscall table in `.rodata`, dispatched via `syscall_dispatch`
by reading `RAX` as the syscall number. Full pipeline (syscalls 0, 1, 2, 4, 5 in sequence) has been verified
end-to-end through the dispatcher in QEMU + GDB.

The R8 register as of this moment is not being used to implement the permission system but the ~next commit will have it done~, actually no, this will take quite some time for me to get done.

---

# Currently usable syscalls

| # | Name | Arguments | Description |
|---|---|---|---|
| 0 | `sys_query_limine_bootloader_info` | none | Queries Limine for the bootloader's name and version string. Populates `bootloader_name`, `bootloader_version`, `bootloader_revision`. |
| 1 | `sys_query_limine_framebuffer` | none | Queries Limine for the first framebuffer's address, dimensions, pitch, bpp, and green channel mask/shift. Populates the `framebuffer_struct_*` scratch variables. |
| 2 | `sys_get_center_of_screen` | `RBX` = text length (pixels = length × 8) | Computes the top-left `(x, y)` needed to center a single-line, 8px-tall string on the current framebuffer. Writes to `pen_x` / `pen_y`. Depends on syscall 1 having already run. |
| 3 | `sys_plot_pixel_green` | `RCX` = x, `RDX` = y | Plots a single green pixel at the given framebuffer coordinates. Internal building block -- mainly called directly by syscall 4, not typically invoked on its own. |
| 4 | `sys_print_ASCII_string_green` | `RBX` = buffer pointer, `RCX` = length, `RDX` = x, `RDI` = y | Renders an ASCII string in green, using a hand-rolled 8x8 bitmap font renderer (`font8x8_basic`), starting at the given coordinates. Calls `sys_plot_pixel` directly (not through the dispatcher) for each lit pixel. Skips `RSI` (the "expected" arg4 slot) in favor of `RDI` for `y`, since `RSI` gets clobbered internally by `sys_plot_pixel` while the string-print loop is still running -- using `RDI` instead avoids a save/reload every single pixel. |
| 5 | `sys_exit` | none | Halts the CPU (`cli` / `hlt` loop). Never returns. |

Syscalls with a data dependency must be called in the correct order -- e.g. syscall 2 requires syscall 1's
output (`framebuffer_struct_width`/`height`), and syscall 4 requires syscall 2's output (`pen_x`/`pen_y`)
if you want centered text.
