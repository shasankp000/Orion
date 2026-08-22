# Orion

An x86-64 kernel, built for the Limine bootloader.

The motivation behind this project is because I am simply tired of both
Windows AND Linux.

-------------------------------------------------------------------

# Project Version

The kernel is at version 0.1.1

------------------------------------------------------------------------

# Project Status

Orion has moved beyond the initial "hello world" kernel stage.

The kernel is currently written primarily in x86-64 assembly and is
being developed incrementally, with each subsystem being built,
understood, tested, and verified in QEMU + GDB before moving on.

Current milestones include:

-   Limine boot protocol integration
-   Framebuffer discovery and direct framebuffer access
-   A hand-written syscall ABI and syscall dispatcher
-   ASCII text rendering using an 8x8 bitmap font
-   Screen clearing
-   An Orion-owned GDT
-   An Orion-owned IDT
-   PIC remapping and IRQ0 configuration
-   PIT timer configuration
-   A working timer interrupt handler
-   A global kernel timer tick counter
-   `sys_delay`, implemented using timer ticks
-   Interrupts enabled with `sti`
-   An Orion-owned 64-bit TSS (Task State Segment), loaded via `ltr`
-   A dedicated Ring 0 kernel stack (`RSP0`) wired into the TSS
-   A complete boot path from Limine entry through Orion's kernel setup
    and `kernel_main`

The current kernel can:

1.  Enter through Limine.
2.  Establish Orion's own GDT.
3.  Reload the kernel code/data segments.
4.  Configure the PIT and PIC.
5.  Construct and load Orion's IDT.
6.  Construct and load Orion's TSS, including a dedicated Ring 0 stack.
7.  Enable interrupts.
8.  Receive timer IRQ0 interrupts.
9.  Increment a kernel-owned timer counter.
10. Use that counter to implement a blocking delay syscall.
11. Query the framebuffer and render text.
12. Clear the framebuffer.
13. Continue executing after the delay and render another message.
14. Halt cleanly through `sys_exit`.

The current source is intentionally heavily commented. The comments are
part of the learning process and document the reasoning behind the
implementation rather than merely describing what each instruction does.

------------------------------------------------------------------------

# Calling conventions

Orion currently uses a custom register-based syscall ABI:

``` text
RAX = syscall number
RBX = arg 1
RCX = arg 2
RDX = arg 3
RSI = arg 4
RDI = arg 5
R8  = permission register (reserved for the future permission model)
RSP = stack provided by Limine

remaining registers are available to individual syscall implementations
```

Argument registers are not required to be used sequentially by every
syscall. The intended convention is generally:

``` text
RBX -> RCX -> RDX -> RSI -> RDI
```

but individual syscalls may use a later register when that makes the
implementation simpler.

`RAX` initially contains the syscall number. Once `syscall_dispatch` has
resolved the syscall target, the syscall implementation is free to use
`RAX` internally.

The syscall table lives in `.rodata` and contains direct pointers to the
syscall implementations.

------------------------------------------------------------------------

# Syscall dispatcher

The dispatcher performs a simple table lookup:

``` text
RAX
 │
 │ syscall number
 V
bounds check
 │
 V
syscall_table[ RAX ]
 │
 │ function address
 V
JMP to syscall
```

Invalid syscall numbers currently terminate the kernel through
`sys_exit`.

The dispatcher itself does not perform a `CALL`; it resolves the syscall
number and jumps directly to the implementation.

------------------------------------------------------------------------

# Currently usable syscalls

| # (RAX)| Name | Arguments | Description |
|---:|---|---|---|
| 0 | `sys_query_limine_bootloader_info` | None | Queries Limine for the bootloader's name, version, and revision. Populates `bootloader_name`, `bootloader_version`, and `bootloader_revision`. |
| 1 | `sys_query_limine_framebuffer` | None | Queries Limine for the first framebuffer and extracts its address, dimensions, pitch, bpp, and colour-channel mask/shift information into Orion's framebuffer state. |
| 2 | `sys_get_center_of_screen` | `RBX` = text length | Computes the top-left `(x, y)` required to center a single-line, 8-pixel-tall string on the current framebuffer. Writes the result to `pen_x` and `pen_y`. Depends on syscall 1 having run first. |
| 3 | `sys_plot_pixel` | `RCX` = x, `RDX` = y, `RSI` = colour mode | Plots a single pixel directly into the framebuffer. Currently supports red, green, blue, and white/default colour handling. It is primarily an internal building block for the text renderer. |
| 4 | `sys_print_ASCII_string` | `RBX` = buffer, `RCX` = length, `RDX` = x, `RDI` = y, `RSI` = colour mode | Renders an ASCII string using the hand-rolled 8x8 bitmap font. Each glyph is processed row-by-row and bit-by-bit, with lit pixels sent to `sys_plot_pixel`. |
| 5 | `sys_exit` | None | Disables interrupts and enters a permanent `cli` / `hlt` loop. This syscall does not return. |
| 6 | `sys_clear_screen` | None | Iterates over the framebuffer and sets every pixel to black. |
| 7 | `sys_delay` | `RBX` = seconds | Blocks execution until the global kernel timer reaches the requested target tick. The target is calculated from the current tick count and `TIMER_TICKS_PER_SEC`. |

### Syscall dependencies

Some syscalls depend on state populated by earlier syscalls:

```text
sys_query_limine_framebuffer
        │
        V
sys_get_center_of_screen
        │
        V
sys_print_ASCII_string
```

`sys_delay` independently depends on the timer subsystem having been initialized and interrupts being enabled.

---

# Framebuffer and text rendering

Orion currently uses the framebuffer supplied by Limine.

The framebuffer response is followed through the Limine response
structures manually in assembly:

``` text
framebuffer_request
        │
        V
framebuffer response
        │
        V
framebuffer pointer array
        │
        V
framebuffer structure
        │
        ├── address
        ├── width
        ├── height
        ├── pitch
        ├── bpp
        └── colour masks/shifts
```

The text renderer uses an 8x8 bitmap font.

For every character:

``` text
character
   │
   V
glyph = font8x8_basic + (ASCII * 8)
   │
   V
8 rows
   │
   V
8 bits per row
   │
   V
set pixel when bit is enabled
```

The renderer therefore does not depend on a graphics library or external
text-rendering subsystem.

------------------------------------------------------------------------

# GDT

Orion now owns its own Global Descriptor Table.

The current kernel descriptors are:

| Selector | Descriptor | Privilege |
|----------|------------|-----------|
|  `0x00`  |   Null descriptor |   ---- |
|  `0x08`  |   Kernel code     |   Ring 0 |
|  `0x10`  |   Kernel data     |   Ring 0 |
|  `0x18`  |   User code       |   Ring 3 (prepared for future userspace) |
|  `0x20`  |   User data       |   Ring 3 (prepared for future userspace) |
|  `0x28`  |   TSS descriptor (lower 64 bits)  |   System |
|  `0x30`  |   TSS descriptor (upper 64 bits)  |   System |

Entries 5 and 6 together form the single 16-byte TSS system descriptor
required in 64-bit long mode (unlike code/data descriptors, a TSS
descriptor does not fit in 8 bytes once the full 64-bit base address is
included). The selector used with `ltr` is `0x28`; the CPU automatically
consults `0x30` for the upper half of the base address and does not need
to be loaded separately.

The GDT is loaded through its GDTR structure using `lgdt`.

After loading Orion's GDT, the kernel reloads its data segment registers
with the kernel data selector and performs the required code-segment
transition so execution continues using Orion's kernel code descriptor.


The GDT is loaded through its GDTR structure using `lgdt`.

After loading Orion's GDT, the kernel reloads its data segment registers
with the kernel data selector and performs the required code-segment
transition so execution continues using Orion's kernel code descriptor.

Conceptually:

``` text
Limine entry
    │
    ▼
Orion GDT
    │
    ├-- 0x08 → Kernel Code
    ├-- 0x10 → Kernel Data
    ├-- 0x18 → User Code
    └-- 0x20 → User Data
```

The user descriptors are groundwork for the eventual Ring 3/userspace
architecture; Orion is not yet running userspace.

------------------------------------------------------------------------

# IDT

Orion also owns its Interrupt Descriptor Table.

The IDT is constructed in kernel memory and loaded with `lidt`.

The timer interrupt currently occupies vector `0x20`.

The relevant gate is a 64-bit interrupt gate containing:

``` text
offset  0:15
CS      = 0x08
IST     = 0
type    = 0x8E
offset 16:31
offset 32:63
```

The kernel code selector used by the interrupt gate is therefore:

``` text
0x08 --> Orion kernel code descriptor
```

The IDT descriptor itself is a 10-byte x86-64 structure:

``` text
16-bit limit
64-bit base
```

This distinction was important during implementation because an
incorrectly sized descriptor caused the CPU to load an invalid IDT base
and resulted in a boot loop/triple-fault path once interrupts were
enabled.

------------------------------------------------------------------------

# TSS (Task State Segment)

Orion now owns a 64-bit TSS, defined in its own file (`tss.inc`) rather
than inline with the GDT, in anticipation of per-CPU TSSes once SMP is
introduced.

In 64-bit long mode the TSS is not used for hardware task switching.
Orion uses it for two purposes:

-   Providing `RSP0`, the stack pointer the CPU loads automatically on a
    Ring 3 → Ring 0 transition (prepared now even though Ring 3 is not
    yet active).
-   Providing IST (Interrupt Stack Table) entries — dedicated stacks for
    specific interrupts/exceptions, independent of whatever stack was in
    use when the interrupt occurred. IST stacks are not yet wired to any
    interrupt vector.

The struct layout:

``` text
0x00  reserved0    4 bytes
0x04  rsp0         8 bytes
0x0C  rsp1         8 bytes
0x14  rsp2         8 bytes
0x1C  reserved1    8 bytes
0x24  ist1..ist7   8 bytes each
0x5C  reserved2    8 bytes
0x64  reserved3    2 bytes
0x66  iomap_base   2 bytes
0x68  END (total size = 104 bytes)
```

Field offsets are computed via label arithmetic (`tss64_field - tss64`)
rather than hardcoded, so the struct can grow without every dependent
constant needing to be manually recalculated.

## TSS descriptor

Unlike code/data descriptors, a TSS descriptor is a 16-byte system
descriptor in long mode, since it must encode a full 64-bit base
address. It occupies two consecutive GDT entries (`0x28`/`0x30`, see the
GDT section above).

## Initialization order

TSS fields are fully populated before the TSS is made "live" via `ltr`,
and interrupts are only enabled after `ltr` completes:

``` text
setup_kernel_stack       (populate RSP0)
        │
        V
setup_tss_descriptor
        │
        ├── populate iomap_base
        └── ltr             (load task register)
        │
        V
sti
```

This ordering matters: if `ltr` executed before `RSP0`/`iomap_base` were
populated, or if `sti` executed before `ltr`, the CPU could consult
TSS state before it was valid.

`RSP0` points at a statically reserved 4KB kernel stack
(`kernel_stack0` / `kernel_stack0_top`), since Orion has no dynamic
allocator yet.

`iomap_base` is set at runtime to `TSS_SIZE` (`0x68`), which tells the
CPU the I/O permission bitmap starts beyond the end of the TSS — i.e.
there is currently no I/O bitmap. This is computed from `TSS_SIZE`
rather than hardcoded, so it stays correct if the struct layout ever
changes.

## Status

-   TSS struct, descriptor, and `ltr` load: implemented and verified.
-   `RSP0`: populated and verified.
-   `iomap_base`: populated and verified.
-   `IST1` and a routed double-fault (`#DF`, vector 8) IDT gate: not
    yet implemented. IST is therefore defined but not yet exercised by
    an actual interrupt.

------------------------------------------------------------------------

# Timer subsystem

Orion now has a working hardware timer.

The timer path currently uses the legacy PC-compatible PIT and 8259 PIC:

``` text
PIT
 |
 | Channel 0
 V
IRQ0
 |
 V
Master PIC
 │
 │ remapped vector
 V
interrupt vector 0x20
 │
 V
IDT[0x20]
 │
 V
timer_interrupt_handler
```

## PIT configuration

The PIT base frequency and divisor are defined as assembly constants:

``` text
PIT_FREQUENCY       = 1193182
PIT_DIVISOR         = 0x2E9B
TIMER_TICKS_PER_SEC = PIT_FREQUENCY / PIT_DIVISOR
```

The current divisor produces approximately 100 timer interrupts per
second, making:

``` text
TIMER_TICKS_PER_SEC = 100
```

The PIT is configured through:

``` text
0x43 → command/mode register
0x40 → Channel 0 data
```

The divisor is sent low byte first, followed by the high byte.

## PIC configuration

The 8259 PIC is remapped so that IRQ0 does not collide with the CPU's
exception vectors.

The master PIC is configured so that IRQ0 is enabled while the other
currently unused master IRQ lines remain masked.

The timer interrupt handler sends an End Of Interrupt command to the
master PIC through its command port:

``` text
0x20
```

------------------------------------------------------------------------

# Timer tick counter

The timer subsystem owns a global kernel state variable:

``` asm
timer_ticks:
    dq 0
```

Every timer interrupt increments it:

``` asm
inc qword [rel timer_ticks]
```

The interrupt handler preserves `RAX` because it needs `AL` to send the
PIC's EOI command:

``` asm
push rax

inc qword [rel timer_ticks]

mov al, 0x20
out 0x20, al

pop rax

iretq
```

The CPU automatically pushes the interrupt-return state when the
interrupt is taken, and `iretq` restores that state when the handler
finishes.

The timer tick counter is therefore the shared timing primitive used by
the kernel's delay mechanism.

------------------------------------------------------------------------

# `sys_delay`

`sys_delay` is the first syscall that actively consumes the timer
subsystem.

Its algorithm is intentionally simple:

``` text
current_ticks = timer_ticks

target_ticks =
    current_ticks +
    (requested_seconds * TIMER_TICKS_PER_SEC)

while timer_ticks < target_ticks:
    wait

return
```

The implementation uses the global tick counter rather than attempting
to measure elapsed time independently.

For example, with:

``` text
TIMER_TICKS_PER_SEC = 100
```

a request for:

``` text
sys_delay(5)
```

waits for approximately:

``` text
5 × 100 = 500 timer ticks
```

The timer interrupt continues to update `timer_ticks` asynchronously
while the syscall is looping.

This is currently a busy-wait implementation. A future scheduler/idle
mechanism can make delays more efficient, but that is intentionally not
being designed yet.

------------------------------------------------------------------------

# Interrupt initialization order

The current hardware setup follows this general sequence:

``` text
configure PIT
     │
     V
remap/configure PIC
     │
     V
construct timer IDT gate
     │
     V
load IDT
     │
     V
return from setup_hardware
     │
     V
initialize timer_ticks
     │
     V
sti
     │
     V
kernel_main
```

Interrupts remain disabled while the interrupt infrastructure is being
constructed.

Only after the IDT, PIC, PIT, and timer state are ready does Orion
execute:

``` asm
sti
```

This prevents the CPU from receiving a timer interrupt before the
corresponding handler and state have been established.

------------------------------------------------------------------------

# Current boot flow

The high-level execution path is now:

``` text
Limine
  │
  ▼
_start
  │
  ├── load Orion GDT
  ├── reload kernel segments
  │
  V
setup_hardware
  │
  ├── configure PIT
  ├── configure PIC
  ├── construct timer IDT entry
  └── load IDT
  │
  V
initialize timer_ticks
  │
  V
setup_kernel_stack (populate TSS RSP0)
  │
  V
setup_tss_descriptor (populate iomap_base, ltr)
  │
  V
sti
  │
  V
kernel_main
  │
  ├── query Limine bootloader information
  ├── query framebuffer
  ├── center text
  ├── print "Hello, from the Orion kernel!"
  ├── delay
  ├── clear screen
  ├── delay
  ├── recalculate text position
  ├── print creator information
  └── sys_exit
```

The current demonstration therefore exercises considerably more of the
kernel than the original hello-world stage.

------------------------------------------------------------------------

# Example kernel demonstration

The current `kernel_main` demonstrates a simple visible sequence:

``` text
1. Display:
       Hello, from the Orion kernel!

2. Wait for 2 seconds.

3. Clear the framebuffer.

4. Wait for 2 seconds.

5. Display:
       Shasank Prasad
```

The exact text and timing are part of the current development test
rather than a permanent user-facing kernel interface.

The important part of the demonstration is that execution now continues
correctly across:

``` text
framebuffer rendering
        ↓
hardware timer interrupts
        ↓
sys_delay
        ↓
screen clearing
        ↓
another delay
        ↓
another syscall sequence
```

------------------------------------------------------------------------

# Debugging and verification

Orion is currently developed and tested using QEMU and GDB.

The development workflow deliberately verifies low-level state instead
of relying only on visible output.

Examples of things currently verified through GDB include:

-   GDT selectors and segment registers
-   IDT descriptor base and limit
-   Individual IDT gate bytes
-   Timer interrupt handler address
-   Timer interrupt execution
-   `timer_ticks` incrementing from `0` to `1` and beyond
-   `RAX` preservation across the timer ISR
-   PIT/PIC initialization flow
-   `sys_delay` target tick calculation
-   `timer_ticks` advancing while `sys_delay` loops
-   syscall dispatch and syscall transitions
-   framebuffer memory contents
-   Task Register (`TR`) contents after `ltr`
-   TSS `RSP0` and `iomap_base` field values after initialization

The timer subsystem was specifically debugged by placing a breakpoint
directly on:

``` text
setup_hardware.timer_interrupt_handler
```

and observing:

``` text
timer_ticks = 0
        ↓
timer interrupt
        ↓
timer_ticks = 1
        ↓
timer interrupt
        ↓
timer_ticks = 2
        ↓
...
```

This confirmed that the interrupt path was not merely configured
syntactically: the PIT was actually generating IRQ0 events and Orion was
successfully receiving and returning from them.

------------------------------------------------------------------------

# Roadmap

The roadmap is deliberately evolutionary rather than a rigid checklist.

Broad areas ahead include:

-   Wire an IST1 stack to a routed double-fault (`#DF`, vector 8) IDT
    gate, completing the IST half of the TSS work.
-   Expand hardware abstraction.
-   Improve interrupt/exception handling.
-   Expand syscall facilities.
-   Establish a proper privilege boundary.
-   Introduce userspace / Ring 3 execution.
-   Develop memory management.
-   Develop paging and kernel/user address-space policy.
-   Introduce a scheduler and task model.
-   Develop process/thread abstractions.
-   Expand device support.
-   Create a dedicated section for mapping windows api syscalls to Orion's syscalls directly at ring 0 (via a different Orion module project: Helium)
-   Eventually build a complete operating-system environment around
    Orion.

The eventual OS built on top of Orion is intended to be substantially
larger than the current kernel. For now, the priority remains learning
and establishing the kernel's fundamental machinery correctly.

------------------------------------------------------------------------

# Project philosophy

Orion is not being built because writing a kernel is the shortest way to
make an operating system.

It is being built because, I the author, want a kernel and OS that allows me to fully own the hardware I paid for, bloat-free and also be able to play any and all windows 
games without performance compromise. I also plan to extend Orion to run on older hardware in the future, but currently it is being built on and for modern hardware.
