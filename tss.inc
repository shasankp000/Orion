; This is the beginning of the TSS (Task State Segment) description
; of the Orion Kernel
; Authored by: Shasank Prasad (only me for now, at least).

section .data

    ; The TSS or the Task State Segment was historically used in x86-64 CPUs to store the
    ; task state/process
    ;
    ;  In 64-bit long mode, we will not use the TSS for hardware task switching
    ;
    ;  Instead we will use the TSS to get:
    ;
    ;   We will use the TSS to pvoide us kernel stack pointers when entering ring 0 from a lower privilege level.
    ;
    ;   The TSS also provides dedicated IST stacks for recovering from exceptions/faults/interrupts when the CPU's own stack is not set up.
    ;
    ;   The TSS also provides an I/O permission bitmap.
    ;
    ;   x86 has a privilege distinction around the I/O ports.
    ;
    ;   So the I/O permission bitmap, maps a permission bit to each I/O port.
    ;
    ;   The permission bits determine whether if a program from a lower privilege level is allowed to access said
    ;   port or not.
    ;
    ;
    ; The TSS Layout:
    ;
    ; Offset
    ; -------------------------------------
    ;
    ; 0x00  reserved0       4 bytes ---> Nothing to assign here, stays 0.
    ;       ------------------------
    ; 0x04  rsp0            8 bytes ----> stack pointer to the ring 0 stack.
    ;       ------------------------
    ; 0x0C  rsp1            8 bytes ----> stack pointer to the ring 1 stack.
    ;       ------------------------
    ; 0x14  rsp2            8 bytes ----> stack pointer to the ring 2 stack.
    ;       ------------------------
    ; 0x1C  reserved1       8 bytes ---> Nothing to assign here, stays 0.
    ;       ------------------------
    ; 0x24  ist1            8 bytes ---> IST stack 1
    ;       ------------------------
    ; 0x2C  ist2            8 bytes ---> IST stack 2
    ;       ------------------------
    ; 0x34  ist3            8 bytes ---> IST stack 3
    ;       ------------------------
    ; 0x3C  ist4            8 bytes ---> IST stack 4
    ;       ------------------------
    ; 0x44  ist5            8 bytes ---> IST stack 5
    ;       ------------------------
    ; 0x4C  ist6            8 bytes ---> IST stack 6
    ;       ------------------------
    ; 0x54  ist7            8 bytes ---> IST stack 7
    ;       ------------------------
    ; 0x5C  reserved2       8 bytes ---> Nothing to assign here, stays 0.
    ;       ------------------------
    ; 0x64  reserved3       2 bytes ---> Nothing to assign here, stays 0.
    ;       ------------------------
    ; 0x66  iomap_base      2 bytes ---> Offset to I/O permission bitmap
    ;       ------------------------
    ; 0x68  END                     ---> Total TSS size = 104 bytes
    ;
    ;
    ; The reason why we don't have offsets as:
    ;
    ; rsp0 = 0x08
    ; rsp1 = 0x10
    ; rsp2 = 0x18
    ;
    ; Is because the initial TSS field, reserved0 begins at 4 bytes, so it's not reserved on a nice 8 bytes boundary.
    ; The IST portion, can be visualized as:
    ;
    ;                TSS
    ;                 |
    ;         ┌-------┴-------┐
    ;         |               |
    ;       RSP0             IST
    ;         |               |
    ;         |        ┌------┼------┬------┐
    ;         |        |      |      |      |
    ;         V        V      V      V      V
    ;    Kernel       IST1   IST2   IST3   ...
    ;     stack
    ;
    ;  So, IST1 is the stack for exception#1
    ;      IST2 is the stack for exception#2
    ;      IST3 is the stack for exception#3
    ;
    ;      and so on...
    ;
    ;  Instead of: "IST1 = stack address chosen by Orion"
    ;
    ; Then, an IDT  ; define the kernel_stack.
    ; For now, let's describe the TSS descriptor and it's fields.

    ; "describe bytes", for NASM, gives us these 4 choices
    ; db    define byte       -> 8 bits (1 byte)
    ; dw    define word       -> 16 bits (2 bytes)
    ; dd    define doubleword -> 32 bits (4 bytes)
    ; dq    define quadword   -> 64 bits (8 bytes)

    ; TSS struct

    align 16
    tss64:
        tss64_reserved0:
            dd 0  ; 0x00 : reserved0   --> 4 bytes

        tss64_rsp0:
            dq 0  ; 0x04   : rsp0      --> 8 bytes

        tss64_rsp1:
            dq 0  ; 0x0C   : rsp1      --> 8 bytes

        tss64_rsp2:
            dq 0  ; 0x14   : rsp2      --> 8 bytes

        tss64_reserved1:
            dq 0  ; 0x1C   : reserved1 --> 8 bytes

        tss64_ist1:
            dq 0  ; 0x24   : ist1      --> 8 bytes

        tss64_ist2:
            dq 0  ; 0x2C   : ist2      --> 8 bytes

        tss64_ist3:
            dq 0  ; 0x34   : ist3      --> 8 bytes

        tss64_ist4:
            dq 0  ; 0x3C   : ist4      --> 8 bytes

        tss64_ist5:
            dq 0  ; 0x44   : ist5      --> 8 bytes

        tss64_ist6:
            dq 0  ; 0x4C   : ist6      --> 8 bytes

        tss64_ist7:
            dq 0  ; 0x54   : ist7      --> 8 bytes

        tss64_reserved2:
            dq 0  ; 0x5C   : reserved2 --> 8 bytes

        tss64_reserved3:
            dw 0  ; 0x64   : reserved3 --> 2 bytes

        tss64_iomap_base:
            dw 0  ; 0x66   : iomap_base --> 2 byte

    tss64_end:

    ; TSS field offsets

    TSS_GDT_INDEX equ 5 ; defines where the first 8 bytes of the TSS descriptor lives in the gdt.
    TSS_SELECTOR  equ TSS_GDT_INDEX << 3 ; simplified explanation: converts the TSS index to a usable selector.
    TSS_RESERVED0  equ tss64_reserved0 - tss64
    TSS_RSP0       equ tss64_rsp0  - tss64
    TSS_RSP1       equ tss64_rsp1  - tss64
    TSS_RSP2       equ tss64_rsp2  - tss64
    TSS_RESERVED1  equ tss64_reserved1 - tss64
    TSS_IST1       equ tss64_ist1  - tss64
    TSS_IST2       equ tss64_ist2 - tss64
    TSS_IST3       equ tss64_ist3 - tss64
    TSS_IST4       equ tss64_ist4 - tss64
    TSS_IST5       equ tss64_ist5 - tss64
    TSS_IST6       equ tss64_ist6 - tss64
    TSS_IST7       equ tss64_ist7 - tss64
    TSS_RESERVED2  equ tss64_reserved2 - tss64
    TSS_RESERVED3  equ tss64_reserved3 - tss64
    TSS_IOMAP_BASE equ tss64_iomap_base - tss64
    TSS_SIZE       equ tss64_end  - tss64
    TSS_LIMIT      equ TSS_SIZE - 1
