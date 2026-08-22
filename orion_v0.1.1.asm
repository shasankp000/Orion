; This is the beginning of the Orion Kernel.
; Ax x86-64 kernel, made by shasankp000 (so far, atleast)

default rel;

%include "fonts/font8x8_basic.inc"
%include "./tss.inc"

section .limine_info_request
    ; limine requests will be here.
    ; need to add the firt 4 LIMINE_REQUESTS_START_MARKER magic markers
    align 8
        dq 0xf6b8f4b39de7d1ae
        dq 0xfab91a6940fcb9cf
        dq 0x785c6ed015d3e316
        dq 0x181e920a7852b9d9

    ; bootloader info request
    align 8
    bootloader_info_request:
        ; let's say I want to fetch info from the bootloader.
        ; we will need to structure the request body as follows
        ; first 4 ids, 2 are header ids
        ; dq 0xc7b1dd30df4c8b88
        ; dq 0x0a82e883a194f07b
        ; these two are constant
        ; the next two are feature specific ids
        ; then we need a revision field
        ; and lastly a response field.
        ; so, for fetching bootloader info
            dq 0xc7b1dd30df4c8b88 ; 0
            dq 0x0a82e883a194f07b ; + 8
            dq 0xf55038d8e2a1202f ; bootloader info specific feature id, +16
            dq 0x279426fcf5f59740 ; bootloader info specific feature id, + 24
            dq 0  ; revision field , +32
            dq 0  ; response field, are these two always supposed to be 0?, +40

    ; framebuffer request
    align 8
    frambuffer_request:
        dq 0xc7b1dd30df4c8b88 ; 0
        dq 0x0a82e883a194f07b ; + 8
        dq 0x9d5827dcd881dd75 ; framebuffer_request specific feature id, +16
        dq 0xa3148604f6fab11b ; frambuffer_request specific feature id, + 24
        dq 0  ; revision field , +32
        dq 0  ; response field, are these two always supposed to be 0?, +40

    ; now we end the request structure with the two LIMINE_REQUESTS_END_MARKER magic markers
    align 8
        dq 0xadc0e0531bb10d03
        dq 0x9572709f31764c62

section .bss

    bootloader_name resb 8
    bootloader_version resb 8
    bootloader_revision resb 8
    framebuffer_revision resb 8
    framebuffer_count resb 8

    ; framebuffer struct variables, we only need these to print text in green color.
    framebuffer_struct_address resb 8;
    framebuffer_struct_height resb 8;
    framebuffer_struct_width resb 8;
    framebuffer_struct_pitch resb 8;
    framebuffer_struct_bpp resb 2 ; two bytes
    framebuffer_struct_red_mask_size resb 1 ; 1 byte only
    framebuffer_struct_red_mask_shift resb 1 ; 1 byte only
    framebuffer_struct_green_mask_size resb 1 ; 1 byte only
    framebuffer_struct_green_mask_shift resb 1 ; 1 byte only
    framebuffer_struct_blue_mask_size resb 1 ; 1 byte only
    framebuffer_struct_blue_mask_shift resb 1 ; 1 byte only

    loop_inner_print_ASCII_character_green_counter resb 8
    loop_middle_print_ASCII_character_green_counter resb 8
    loop_outer_print_ASCII_character_green_counter resb 8

    pen_x resb 8
    pen_y resb 8

    ; Kernel stack pointer stuff, for IST.
    ; Since we are only in a single core:
    kernel_stack0:
        resb 4096
    kernel_stack0_top:

    ; This will give us:
    ;   kernel_stack
    ;         |
    ;         V
    ;   ┌------------------┐
    ;   |                  |
    ;   |    4096 bytes    |
    ;   |                  |
    ;   └------------------┘
    ;                      ^
    ;                      |
    ;                kernel_stack_top

    ; Since x86-64 stacks grow downward,
    ; kernel_stack_top is what we eventually want in:
    ; tss64.rsp0, the ring 0 stack pointer. gate (from the IDT we configured earlier) can say:
    ;
    ; (for IST = 1), When this particular interrupt/trap occurs, switch to TSS.IST1.
    ;
    ; Now as for what exceptions each IST stack can be designated to, that's our own convetion, and can be
    ; decided upon, later.

section .rodata
    ; This section contains read-only data.

    ; "describe bytes", for NASM, gives us these 4 choices
    ; db    define byte       -> 8 bits (1 byte)
    ; dw    define word       -> 16 bits (2 bytes)
    ; dd    define doubleword -> 32 bits (4 bytes)
    ; dq    define quadword   -> 64 bits (8 bytes)

    orion_kernel_version db "version: 0.1.1", 10
    orion_kernel_version_length equ $ - orion_kernel_version

    orion_hello_message db "Hello, from the Orion kernel!", 10
    orion_hello_message_length equ $ - orion_hello_message

    orion_creator_name db "Created by: Shasank Prasad", 10
    orion_creator_name_length equ $ - orion_creator_name

    orion_creation_date db "Created on: 15/08/2026", 10
    orion_creation_date_length equ $ - orion_creation_date

    ; Timer configuration
    PIT_FREQUENCY       equ 1193182
    PIT_DIVISOR         equ 0x2E9B
    TIMER_TICKS_PER_SEC equ PIT_FREQUENCY / PIT_DIVISOR

    syscall_table:
        dq sys_query_limine_bootloader_info ; syscall 0
        dq sys_query_limine_framebuffer     ; syscall 1
        dq sys_get_center_of_screen         ; syscall 2
        dq sys_plot_pixel                   ; syscall 3
        dq sys_print_ASCII_string           ; syscall 4
        dq sys_exit                         ; syscall 5
        dq sys_clear_screen                 ; syscall 6
        dq sys_delay                        ; syscall 7

    syscall_table_end:
        %define SYSCALL_COUNT ((syscall_table_end - syscall_table) / 8)

section .data
    ; writeable data section

    ; "describe bytes", for NASM, gives us these 4 choices
    ; db    define byte       -> 8 bits (1 byte)
    ; dw    define word       -> 16 bits (2 bytes)
    ; dd    define doubleword -> 32 bits (4 bytes)
    ; dq    define quadword   -> 64 bits (8 bytes)

    ; Orion's Global Descriptor Table creation
    align 8
    gdt:
        ; each entry in the gdt is a 64-bit entry
        ; and every descriptor is 8 bytes long.
        ; entry_offset = entry_number × sizeof(descriptor)
        dq 0 ; Entry 0: The null descriptor ; 0x00

        ; there's a bit of explanation to be done before constructing our kernel descriptor's
        ; magic number
        ; I don't want this to appear as some of dark magic, so let's understand what each of the bits mean in the kernel descriptor
        ; and which bits do we actually mean and which bits are just filled in since we are constructing the full 64-bit magic number
        ; 64-bit GDT segment descriptor
        ;------------------------------------------------------------------------
        ;
        ;63                         56 55 52 51      48 47      40 39      32
        ;┌─--------------------------------------------------------------------─┐
        ;│        Base 31:24          │Flags │Limit    │ Access   │  Base 23:16 │
        ;│                            │      │  19:16  │  byte    │             │
        ;└─--------------------------------------------------------------------─┘
        ;
        ;31                         24 23                  16 15                  0
        ;┌─-----------------------------------------------------------------------─┐
        ;│        Base 23:16          │     Base 15:0        │    Limit 15:0       │
        ;└─-----------------------------------------------------------------------─┘
        ;
        ; Now these bit ranges have different meanings, and there's a LOT to absorb and
        ; and document here but I will keep things strictly on a need-to-know basis for the
        ; moment,
        ;
        ; Bits  0–15 --> Limit 15:0
        ; Bits 16–31 --> Base 15:0
        ; Bits 32–39 --> Base 23:16
        ; Bits 40–47 --> Access byte
        ; Bits 48–51 --> Limit 19:16
        ; Bits 52–55 --> Flags
        ; Bits 56–63 --> Base 31:24
        ;
        ;  P = (present bit) (tells if the descriptor is present or not). Accepts 0/1
        ;  DPL = Descriptor Privilege level, tells the cpu which layer of Privilege the descriptor has:
        ;  DPL = 00 for Ring 0
        ;  DPL = 01 for Ring 1
        ;  DPL = 10 for Ring 2
        ;  DPL = 11 for Ring 3
        ;  DPL=3 doesn't itself magically put the CPU into Ring 3.
        ;  It establishes that this descriptor belongs to the user privilege level.
        ;  Later, when we actually transition from Ring 0 --> Ring 3, we'll have to use
        ;  the appropriate mechanism and load the corresponding selectors.
        ;  That's where these 0x18 and 0x20 selector values will become meaningful.
        ;  S bit = The code/data descriptor bit tells the system if the segment is code or data. S = 1 means it's code
        ;  Type(E) bit = Tells the CPU if the code is executable or not. E = 1 means it's executable
        ;  R bit = Tells the CPU if the code is only readable or R/W (read and write).
        ;  For code segment, R = 1 means the code is readable only, R = 0 means execute only
        ;  For a data segment, R = 1 means the data is writable, R = 0 means the data is read-only.
        ;  DC bit --> Conforming segments
        ;  Conforming segments are an older x86 privilege mechanism that
        ;  allows code at a lower privilege level to execute code belonging
        ;  to a higher-privilege segment under specific rules.
        ;  DC = 0 non-conforming code
        ;  DC = 1 conforming code.
        ;  We don't need DC for Orion's kernel code though.
        ;  A = Acessed bit, this bit tells software whether the CPU has accessed the segment.
        ;  A = Accessed bit.
        ;
        ;  The CPU sets this bit to 1 when the segment is loaded into a
        ;  segment register such as CS, DS, ES or SS.
        ;
        ;  We can initialize it to 0 and allow the CPU to set it.
        ;
        ;  HOWEVER:
        ;
        ;  If the GDT is stored in read-only memory, the CPU cannot modify
        ;  the descriptor to set A = 1. This can cause a page fault.
        ;
        ;  Therefore, if the GDT is in read-only memory, we can initialize
        ;  A = 1 ourselves.
        ;  But the better thing to do is to just NOT define the GDT in read-only data section.
        ;  We initially set A to 0 and then CPU over-writes this bit as it accesses code segment.
        ;
        ; So the access byte looks like this:
        ;
        ; 47 46 45 44 43 42 41 40
        ; ┌--┬----┬---┬--┬--┬--┬--┐
        ; │ P│ DPL│ S │ E│DC│ R│ A│
        ; └--┴----┴---┴--┴--┴--┴--┘
        ;
        ; Considering Orion's kernel code our Access byte will come out as:
        ;
        ;  1 00 1 1 0 1 0
        ;
        ; Now the Flags
        ;
        ;  55  54  53  52
        ; ┌--┬---┬---┬---┐
        ; │ G│ D │ L │AVL│
        ; └--┴---┴---┴---┘
        ;
        ; G = Granularity G controls the unit in which the segment Limit is interpreted.
        ; The Limit field is 20 bits wide, but G determines whether those 20 bits represent bytes or 4-KiB pages.
        ;
        ; For normal 64-bit code/data segments, base and limit don't provide the memory isolation mechanism anymore.
        ; Paging does that.
        ;
        ; For the actual flat descriptor though, we need to set G = 1 as per the convention.
        ;
        ; D controls the default operand/address size for a legacy code segment.
        ;
        ; However since we are running in 64-bit long mode, L takes precedence and tells the CPU
        ; to execute the code in 64-bit long mode. Hence D = 0.
        ;
        ; L = tells the CPU if the descriptor is in 64-bit long mode or not.  Accepts 0/1
        ;
        ; AVL = Availability to software
        ; It is a bit that the CPU essentially provides for software's own use.
        ; Operating systems can use it for their own bookkeeping if they want.
        ; As of the moment we are not using it yet.
        ; So we set AVL to 0.
        ;
        ; Lastly, base and Limit (from Granularity).
        ;
        ;           Base
        ;            |
        ;            V
        ;    Memory -┼--------------------------─┐
        ;            |                           |
        ;            |         Segment           |
        ;            |                           |
        ;            └--------------------------─┤
        ;                                        |
        ;                                        V
        ;                                    Base + Limit
        ;
        ; The Base specifies the starting address of the segment.
        ; For base = 0x100000, it would mean the segment starts at that address
        ;
        ; The Limit specifies how far the segment extends.
        ;
        ; For example:
        ; Base  = 0x100000
        ; Limit = 0xFFFF
        ; would describe a segment through
        ; 0x100000 --> 0x10FFFF
        ;
        ; But in modern x86-64 assembly, especially in 64-bit long mode most of segmentation is already disabled
        ; And we can get memory protection and isolation from paging.
        ; so we just set base to 0 then.
        ; and limit to 0xFFFF (16 bits) (bits 0 to 15)
        ; and limit to just 0xF (for the remaining upper 4 bits of the limit) (bits 48-51)
        ; so the total Limit size comes down to 20 bits.
        ;
        ; Constructing all these in the given order.
        ;
        ; Read this number backwards from bit 63 down to 0
        ;
        ; base bits 63 to 54: 0
        ;
        ; 00000000000
        ;
        ; bits 55 to 52, flags:
        ;
        ; G D L AVL
        ;
        ; 1 0 1 0
        ;
        ; Bit 48 to 51: upper 4 bits of limit
        ;
        ; F = 1111
        ;
        ; Bits 47 to 40, the access byte:
        ;
        ; 1 00 1 1 0 1 0 -> 9A --> 0x9A
        ;
        ; Bits 39-32, base : all zero
        ;
        ; 00000000
        ;
        ; Bits 31 to 16, base: all zero
        ;
        ; 0000000000000000
        ;
        ; Bits 15 to 0, 16 bit limit: FFFF --> 1111 1111 1111 1111
        ;
        ; So our final kernel descriptor code becomes:
        ;
        ; 0000000000010101111100110100000000000000000000000001111111111111111 in binary
        ;
        ; or 0x00AF9A000000FFFF in hexadecimal


        dq 0x00AF9A000000FFFF ; Entry 1: The kernel code segment ; 0x08

        ; for the kernel data segment we need a similar magic value with these bits changed in the access-byte
        ; S = 1 (code/data descriptor)
        ; E = 0 (not executable, data)
        ; R = 1 (read/write)
        ; The data descriptor cannot have L = 1.
        ; L = 1 designates a 64-bit code segment.
        ; Attempting to load this descriptor as a data segment causes a #GP (General Protection Fault).
        ; Because L specifically means "64-bit code segment."
        ; It isn't a general-purpose "this segment is used while the CPU is in 64-bit mode" flag.
        ;
        ; so:
        ;
        ; 47 46 45 44 43 42 41 40
        ; ┌--┬----┬---┬--┬--┬--┬--┐
        ; │ P│ DPL│ S │ E│DC│ R│ A│
        ; └--┴----┴---┴--┴--┴--┴--┘
        ;
        ; Earlier we had for the access byte:
        ;
        ;  1 00 1 1 0 1 0 (for the kernel code descriptor)
        ;
        ; Now we will have for the access byte :
        ;
        ;  1 00 1 0 0 1 0 -> only one bit flipped.
        ;
        ; bits 55 to 52, flags:
        ;
        ; G D L AVL
        ;
        ; 1 0 0 0
        ;
        ; again, only a single bit flipped.
        ;
        ; So our magic number will be:
        ;
        ; 0000000000010001111100100100000000000000000000000001111111111111111 in binary
        ;
        ; 8F92000000FFFF in hexadecimal
        ;
        ; or 0x008F92000000FFFF in hexadecimal

        dq 0x008F92000000FFFF ; Entry 2: The kernel data segment ; 0x10

        ; now we head into userspace!
        ;
        ; We will have the same logic for constructing the magic numbers, except
        ; the DPL (Descriptor Privilege Level) will shift from 00 to 11 for Ring 3
        ; which is where userspace lies at.

        ; so:
        ;
        ; 47 46 45 44 43 42 41 40
        ; ┌--┬----┬---┬--┬--┬--┬--┐
        ; │ P│ DPL│ S │ E│DC│ R│ A│
        ; └--┴----┴---┴--┴--┴--┴--┘
        ;
        ;  Earlier we had for the access byte:
        ;
        ;  1 00 1 1 0 1 0 (for the kernel code descriptor)
        ;
        ;  1 11 1 1 0 1 0 (for the user-space code descriptor)
        ;
        ; 0000000000010101111111110100000000000000000000000001111111111111111 in binary
        ;
        ; AFFA000000FFFF in hexadecimal
        ;
        ; or 0x00AFFA000000FFFF in hexadecimal

        dq 0x00AFFA000000FFFF ; Entry 3: The user code segment ; 0x18

        ; same as the kernel-data segment, we flip E to 0 in the access byte
        ; and L to 0 in the flags
        ; and DPL = 11 of-course.
        ;
        ; so:
        ;
        ; 47 46 45 44 43 42 41 40
        ; ┌--┬----┬---┬--┬--┬--┬--┐
        ; │ P│ DPL│ S │ E│DC│ R│ A│
        ; └--┴----┴---┴--┴--┴--┴--┘
        ;
        ; Earlier we had for the access byte:
        ;
        ;  1 11 1 1 0 1 0 (for the user-space code descriptor)
        ;
        ; Now we will have for the access byte :
        ;
        ;  1 11 1 0 0 1 0 -> only one bit flipped.
        ;
        ; bits 55 to 52, flags:
        ;
        ; G D L AVL
        ;
        ; 1 0 0 0
        ;
        ; 0000000000010001111111100100000000000000000000000001111111111111111 in binary
        ;
        ; 8FF2000000FFFF in hexadecimal
        ;
        ; or 0x008FF2000000FFFF in hexadecimal

        dq 0x008FF2000000FFFF ; Entry 4: The user data segment ; 0x20

        ; and there we have our GDT described.
        ; actually, we will need two more slots, for the TSS descriptor to be attached to the GDT.
        ; so we reserve them:
        dq 0 ; Lower 64 bits of the TSS descriptor. Offset at gdt: 0x28
        dq 0 ; Upper 64 bits of the TSS descriptor. Offset at gdt: 0x30

    gdt_end:

    gdt_descriptor:
        dw gdt_end - gdt - 1
        dq gdt

    ; Describing the Interrupt Descriptor Table now

    align 16

    idt:
        times 256 dq 0, 0 ; times n tells NASM do something n times, in this instance it tells NASM to generate the same 8 bytes copy 256 times
        ; so we have
    idt_end:

    idt_descriptor:
        dw idt_end - idt - 1
        dq idt

    timer_ticks:
        dq 0 ; the timer tick state, owned by the kernel.

section .text
    global _start

syscall_dispatch:
    cmp rax, SYSCALL_COUNT
    jae .invalid_syscall

    imul rax, rax, 8
    mov rax, [syscall_table + rax]

    jmp rax

.invalid_syscall:
    jmp sys_exit

sys_clear_screen:
    ;
    ; A method that will clear the screen
    ;
    ; sys_clear_screen():
    ;
    ;    start_x = 0
    ;    start_y = 0
    ;
    ;    stop_x = framebuffer_struct_width
    ;    stop_y = framebuffer_struct_height
    ;
    ;    for y = start_y; y < stop_y; y++:
    ;        for x = start_x; x < stop_x; x++:
    ;
    ;            set pen_x = x
    ;            set pen_y = y
    ;            call sys_plot_pixel(pen_x, pen_y, 4) ; 4 is now black color
    ;
    ;
    ;    ret

    ; loop counters
    ; r13 = outer loop counter
    ; r14 = inner loop counter
    mov r13, 0
    mov r14, 0
    mov rsi, 4 ; black color mode
    jmp .loop_outer_clear_screen

.loop_outer_clear_screen:
    cmp r13, [framebuffer_struct_width]
    ; reset r14 to zero
    mov r14, 0
    jge .done_loop_outer_clear_screen
    jl .loop_inner_clear_screen ; jump if less than

.loop_inner_clear_screen:
    cmp r14, [framebuffer_struct_height]
    jge .done_loop_inner_clear_screen

    ; clear screen
    mov rcx, r13 ; fixed row
    mov rdx, r14 ; every column
    mov rax, 3
    call syscall_dispatch

    inc r14
    jmp .loop_inner_clear_screen

.done_loop_outer_clear_screen:
    ret

.done_loop_inner_clear_screen:
    inc r13
    jmp .loop_outer_clear_screen

sys_get_center_of_screen:
    ; rbx = length of input text
    ; rcx = (width - (length * 8)) / 2
    ; rdx = (height - 8) / 2 --> although redundant storing in rdx
    ; rsi = temporary move register
    ; computing pen_x and pen_y as such to display the message on the center of the screen
    ; compute pen_x : (width - (length * 8)) / 2

    mov rsi, [framebuffer_struct_width]
    imul rbx, rbx, 8 ; length * 8
    sub rsi, rbx ; (width - (length * 8))
    shr rsi, 1 ; (width - (length * 8)) / 2
    mov rcx, rsi ; rcx = (width - (length * 8)) / 2

    mov [pen_x], rcx

    ; compute pen_y : (height - 8) / 2

    mov rsi, [framebuffer_struct_height]
    sub rsi, 8 ; (height - 8)
    shr rsi, 1 ; (height - 8) / 2

    mov [pen_y], rsi ; I did not do mov rdx, rsi, since that's just wasteful

    ret

sys_print_ASCII_string:
    ; sys_print_ASCII_string_green(char *buffer, int length, int x, int y)

    ; following documentation is pre-establishment of syscall ABI
    ; this subroutine will work on a loop, as follows
    ;
    ; for each character in the string:
    ;     look up that character's 8-byte glyph in font font8x8_basic
    ;     for each row (0-7) of that glyph:
    ;         load the row's byte
    ;         for each column/bit (0-7) in that byte:
    ;             if bit is set: plot_pixel(pen_x + col, pen_y + row)
    ;     advance pen_x by 8 (move to the next character's position)
    ; calling convention
    ; registers available to us at this point are:
    ; rbp, and r8 through r15.
    ; and we can also use scratch variables in .bss if we don't want to juggle too many registers
    ; there are 3 loops, so we will need 3 labels and 3 corresponding done labels
    ; now let's setup the calling convention
    ; one register for tracking the current character in the string buffer
    ; we need not use a register to store the length as it's already defined in .rodata
    ; but we will need one register to use and have it zero-indexed?
    ; we will need another register to move across each rows of the glyph
    ; another one for moving within the current row of the glyph
    ; another one to store the current row's byte
    ; another register to navigate the bits in that byte
    ; another register to store pen_x (persisting)
    ; another register to store pen_y for now.
    ; then check if the bit is set (how?)
    ; 7 registers being used here then.
    ; actual work starts here
    ; character pointer


    ; calling convention
    ; rbx = buffer pointer
    ; rcx = length
    ; rdx = x
    ; rdi = y
    ; rsi = 0/1/2/3 (red, green, blue, white), color mode

    mov rbp, rbx ; currently at [message+0]
    mov r8, rcx
    mov [pen_x], rdx
    mov [pen_y], rdi
    mov r13, 0 ; outer loop counter
    mov r14, 0 ; middle loop counter
    mov r15, 0 ; inner loop counter
    mov [loop_outer_print_ASCII_character_green_counter], r13
    mov [loop_middle_print_ASCII_character_green_counter], r14
    mov [loop_inner_print_ASCII_character_green_counter], r15
    dec r8 ; zero index the length
    jmp .loop_outer_print_ASCII_character_green

.loop_outer_print_ASCII_character_green:
    ; now how do I access the first row of the glyph?
    ; okay first I have to find out, "what glyph"?
    ; that can be done by finding the ASCII code of each letter as we proceed through the string
    mov r14, 0 ; middle loop counter
    ; reset to zero for each glyph
    mov [loop_middle_print_ASCII_character_green_counter], r14
    cmp r13, r8
    jge .done_loop_outer_print_ASCII_character_green
    movzx r9, byte [rbp]
    ; now we convert this ASCII code to an offset for the glypth table inside font8x8_basic
    ; for a character, c, that would work as font8x8_basic + (c * 8), since each glyph is exactly 8 bytes
    imul r9, r9, 8 ; multiply r9 times 8
    lea r11, [font8x8_basic + r9] ; load the address of the corresponding glyph into r11
    mov [loop_outer_print_ASCII_character_green_counter], r13 ; save counter value to memory
    call .loop_middle_print_ASCII_character_green ; using call instead of jmp
    mov r13, [loop_outer_print_ASCII_character_green_counter] ; read counter value from memory
    inc r13
    mov [loop_outer_print_ASCII_character_green_counter], r13 ; save counter value to memory
    inc rbp ; instead of calculating the effective address of the next character, we just increment the pointer by 1
    ; this is analogous to :
    ; char *buf = some buffer
    ; char next_char = buf+1;


    ; increment [pen_x] by 8 to to get the next x coordinate for the next character
    mov rdx, [pen_x]
    add rdx, 8
    mov [pen_x], rdx

    jmp .loop_outer_print_ASCII_character_green

.loop_middle_print_ASCII_character_green:
    ; now that we have the first glyph row, we need to load it's byte
    ; we will load this byte into r10
    ; but how do I access this byte here?
    mov r15, 0 ; inner loop counter
    ; reset to zero for each byte within the glyph
    mov [loop_inner_print_ASCII_character_green_counter], r15
    cmp r14, 8
    jge .done_loop_middle_print_ASCII_character_green
    ; this is how I will access the byte of the glyph
    movzx r10, byte [r11 + r14]   ; r10 = row r14's byte
    mov [loop_middle_print_ASCII_character_green_counter], r14
    call .loop_inner_print_ASCII_character_green
    mov r14, [loop_middle_print_ASCII_character_green_counter]
    inc r14
    mov [loop_middle_print_ASCII_character_green_counter], r14
    jmp .loop_middle_print_ASCII_character_green

.loop_inner_print_ASCII_character_green:
    mov [loop_inner_print_ASCII_character_green_counter], r15
    cmp r15, 8
    jge .done_loop_inner_print_ASCII_character_green
    ; for each column's bit, how do I access each bit?
    mov r13, 1 ; create a bit mask
    mov rcx, r15 ; we need r15's bit, which would be in cl
    ; then how do I check if the bit is set?
    shl r13, cl
    test r10, r13
    jz .skip_pixel ; skip pixel will act as a "continue"

    ; now call plot_pixel
    ; plot_pixel(pen_x + col, pen_y + row)
    ; r14 and r15 are uncompromised, only r13 is being mutated multiple times.
    mov rcx, [pen_x]
    add rcx, r15 ; rdi = pen_x + column (our x)
    mov rdx, [pen_y]
    add rdx, r14 ; rsi = pen_y + row (our y)
    ; plot_pixel's reserved registers will be safe to use now.
    call sys_plot_pixel

    inc r15
    mov [loop_inner_print_ASCII_character_green_counter], r15
    jmp .loop_inner_print_ASCII_character_green

.skip_pixel:
    inc r15
    mov [loop_inner_print_ASCII_character_green_counter], r15
    jmp .loop_inner_print_ASCII_character_green

.done_loop_outer_print_ASCII_character_green:
    ret
.done_loop_middle_print_ASCII_character_green:
    ret
.done_loop_inner_print_ASCII_character_green:
    ret

sys_plot_pixel:
    ; This should be a protected syscall later.
    ; This syscall plots pixels with the green color on them.

    ; Clobbers: rbx, rcx, rdx, and rsi so callers must save these registers beforehand.
    ; method to plot a pixel given the x and y coordinates.
    ; the pixel plotting math is as follows.
    ; we find out the pixel address via:
    ; offset = (y * pitch) + (x * bytes_per_pixel)
    ; pixel_address = framebuffer_struct_address + offset
    ; so, for this, let our calling convention be
    ; rbx = offset (and later to be used as the pixel address when we add the framebuffer_struct_address)
    ; rcx = x, then (x * bytes_per_pixel)
    ; rdx = y, then (y * pitch)
    ; rsi = color mode; 0 for red, 1 for green, 2 for blue, 3, for default, white, will be passed down from printer subroutine or can be set during direct syscall
    ; rdi = (temporary move register) (not called)
    ; the mul operation uses rax register implicitly to store result of multiplications
    ; but since rax has been reserved for syscall number (although rax becomes free once the syscall has been dispatched)
    ; we will use imul.
    mov rdi, [framebuffer_struct_pitch]
    imul rdx, rdi ; (reads y), the value of (y * pitch) is saved to the rcx register

    ; now we need to find bytes_per_pixel.
    ; but out bpp is "bits" per pixel not bytes
    ; but memory addressing works in bytes!
    ; we cannot do something like "gimme byte 6.5 from the array"
    ; so we convert the bits to bytes by dividing by 8.
    ; a faster and cheaper alternative to using div is just shr (shift right)
    ; shr will shift the bits to the right, each shift is a divison by 2.
    ; since our bpp value will never be odd, so we can safely use shr
    movzx rdi, word [framebuffer_struct_bpp] ; using movzx again since the bpp value is just 2 bytes and our rbx register is not.
    shr rdi, 3 ; shift right 3 times, divide by 8, rbx now becomes bytes_per_pixel
    imul rcx, rdi ; (x * bytes_per_pixel)
    ; used imul here because it takes two operands,

    add rcx, rdx ; offset = (y * pitch) + (x * bytes_per_pixel)
    mov rbx, rcx ; rbx = offset, at this point, rcx and rdx are free
    mov rdi, [framebuffer_struct_address] ; framebuffer_struct_address
    add rbx, rdi ; final pixel address

    ; rcx and rdx are free beyond this point

    ; now colouring our pixel in red/green/blue.
    ; here is how a 32-bit pixel value is split across color channels
    ; bit: 31......24 23......16 15......8 7......0
    ;      [ unused ] [  red   ] [ green ] [ blue ] <-- example layout
    ;  The exact channel order remains to be yet confirmed, but for our case
    ;  the green channel is sitting between 15 and 8.
    ; so we need to put 0xFF, the value of max intensity, into the bits from 15 to 8.
    ; shifting 0xFF left by 8 to give us 0x0000FF00, and this is useful since shl is used to position a value
    ; between a specific range

    ; check color mode
    cmp rsi, 0
    je .color_red
    ; for negative values of rsi
    jle .color_default

    cmp rsi, 1
    je .color_green

    cmp rsi, 2
    je .color_blue

    cmp rsi, 3
    je .color_default

    ; black color
    cmp rsi, 4
    je .color_black

    ; default white color (for other values of rsi greater than 4, defaults to white as of now)
    cmp rsi, 5
    jge .color_default

.color_red:
    ; shift 0xFF by the low byte of the green mask shift of the framebuffer
    mov rcx, [framebuffer_struct_red_mask_shift]
    mov rdx, 0xFF
    shl rdx, cl ; cl holds the low 8 bits of rcx (the green mask shift range), and this is an x86 design choice. Weird.


    mov [rbx], edx ; move the 4-byte color value to a 32-bit register? What is edx doing here?
    ; okay so since our pixel color value was built in a 64-bit register
    ; but the pixel on a 32bpp framebuffer only occupies 4 bytes in memory, so
    ; if we did mov [rax], rdx, we would over-write all 8 bytes into memory at the starting pixel address
    ; so the extra 4 bytes would overwrite the next pixel.

    ret

.color_green:
    ; shift 0xFF by the low byte of the green mask shift of the framebuffer
    mov rcx, [framebuffer_struct_green_mask_shift]
    mov rdx, 0xFF
    shl rdx, cl ; cl holds the low 8 bits of rcx (the green mask shift range), and this is an x86 design choice. Weird.


    mov [rbx], edx ; move the 4-byte color value to a 32-bit register? What is edx doing here?
    ; okay so since our pixel color value was built in a 64-bit register
    ; but the pixel on a 32bpp framebuffer only occupies 4 bytes in memory, so
    ; if we did mov [rax], rdx, we would over-write all 8 bytes into memory at the starting pixel address
    ; so the extra 4 bytes would overwrite the next pixel.

    ret

.color_blue:
    ; shift 0xFF by the low byte of the green mask shift of the framebuffer
    mov rcx, [framebuffer_struct_blue_mask_shift]
    mov rdx, 0xFF
    shl rdx, cl ; cl holds the low 8 bits of rcx (the green mask shift range), and this is an x86 design choice. Weird.


    mov [rbx], edx ; move the 4-byte color value to a 32-bit register? What is edx doing here?
    ; okay so since our pixel color value was built in a 64-bit register
    ; but the pixel on a 32bpp framebuffer only occupies 4 bytes in memory, so
    ; if we did mov [rax], rdx, we would over-write all 8 bytes into memory at the starting pixel address
    ; so the extra 4 bytes would overwrite the next pixel.

    ret

.color_black:
    ; needs all three channels to be set to min simultaneously

    ; shift 0x00 by the low byte of the green mask shift of the framebuffer
    ;    mov rcx, [framebuffer_struct_red_mask_shift]
    ;    mov rdx, 0x00
    ;    shl rdx, cl ; cl holds the low 8 bits of rcx (the green mask shift range), and this is an x86 design choice. Weird.
    ;    mov rax, rdx ; rax is free to use internally

    ; shift 0x00 by the low byte of the green mask shift of the framebuffer
    ;    mov rcx, [framebuffer_struct_green_mask_shift]
    ;    mov rdx, 0x00
    ;    shl rdx, cl ; cl holds the low 8 bits of rcx (the green mask shift range), and this is an x86 design choice. Weird.
    ;    or rax, rdx ; bitwise OR, 1 OR 1 = 1

        ; shift 0x00 by the low byte of the green mask shift of the framebuffer
    ;    mov rcx, [framebuffer_struct_blue_mask_shift]
    ;    mov rdx, 0x00
    ;    shl rdx, cl ; cl holds the low 8 bits of rcx (the green mask shift range), and this is an x86 design choice. Weird.
    ;    or rax, rdx ; bitwise OR, 1 OR 1 = 1

    ; the above stuff works, and is mathematically valid, but computationally redundant
    ; still I am keep that block as commments
    ; a faster way to do this just:

    mov eax, 0 ; guard, even though eax should 0 at this stage, a manual mov secures against any edge cases
    mov [rbx], eax ; not edx this time since we need the low 4 bytes stored in rax

    ret

.color_default:
    ; needs all three channels to be set to max simultaneously

    ; shift 0xFF by the low byte of the green mask shift of the framebuffer
    mov rcx, [framebuffer_struct_red_mask_shift]
    mov rdx, 0xFF
    shl rdx, cl ; cl holds the low 8 bits of rcx (the green mask shift range), and this is an x86 design choice. Weird.
    mov rax, rdx ; rax is free to use internally

    ; shift 0xFF by the low byte of the green mask shift of the framebuffer
    mov rcx, [framebuffer_struct_green_mask_shift]
    mov rdx, 0xFF
    shl rdx, cl ; cl holds the low 8 bits of rcx (the green mask shift range), and this is an x86 design choice. Weird.
    or rax, rdx ; bitwise OR, 1 OR 1 = 1

    ; shift 0xFF by the low byte of the green mask shift of the framebuffer
    mov rcx, [framebuffer_struct_blue_mask_shift]
    mov rdx, 0xFF
    shl rdx, cl ; cl holds the low 8 bits of rcx (the green mask shift range), and this is an x86 design choice. Weird.
    or rax, rdx ; bitwise OR, 1 OR 1 = 1

    mov [rbx], eax ; not edx this time since we need the low 4 bytes stored in rax

    ret

sys_query_limine_framebuffer:
    ; now I am free to use the registers from rbx through rdx
    ; do I need to preserve rax as well, since I have effectively extracted what I need from the bootloader response?
    ; answer: nope, don't need that pointer anymore.

    ; so I can do this then?
    ; yep!

    ; Orion syscall ABI, registers from rbx onwards will either take arguments
    ; or handle stuff internally.
    ; rax is ONLY for taking in syscall numbers (but becomes free to use interally post dispatch)

    mov rbx, [frambuffer_request + 40] ; response field
    test rbx, rbx
    jz no_response
    mov rcx, [rbx+0] ; revision
    mov rdx, [rbx+8] ; number of framebuffers
    mov rsi, [rbx+16] ; array of framebuffers

    mov [framebuffer_revision], rcx
    mov [framebuffer_count], rdx

    ; the framebuffer's struct address is at rsi ([rsi + 0])
    mov rbx, [rsi+0] ; move the actual struct to rbx
    ; now I can use an intermediate register + pointer hopping to get all the data I need

    mov rcx, [rbx+0] ; address
    mov [framebuffer_struct_address], rcx

    mov rcx, [rbx+8] ; width
    mov [framebuffer_struct_width], rcx

    mov rcx, [rbx+16] ; height
    mov [framebuffer_struct_height], rcx

    mov rcx, [rbx+24] ; pitch
    mov [framebuffer_struct_pitch], rcx

    movzx rcx, word [rbx+32] ; bpp
    ; movzx is move with zero extend, fills out unnecessary bits with 0 instead of being stored as garabge values when moving a smaller value to a larger register
    ; it also needs a size operand since unlike plain mov, NASM cannot infer the source width from context, so it needs to know
    ; exactly how many bytes to zero extend from.
    ; word is 2 bytes (16-bits)
    mov [framebuffer_struct_bpp], cx ; cx holds exactly 2 bytes, not using rax here since we would then be writing extra garbage

    ; red
    movzx rcx, byte [rbx+35] ; red_mask_size
    ; byte, is well, 1 byte (8-bits).
    mov [framebuffer_struct_red_mask_size], cl ; cl holds exactly 1 byte

    movzx rcx, byte [rbx+36] ; red_mask_shift
    mov [framebuffer_struct_red_mask_shift], cl

    ; green
    movzx rcx, byte [rbx+37] ; green_mask_size
    ; byte, is well, 1 byte (8-bits).
    mov [framebuffer_struct_green_mask_size], cl ; cl holds exactly 1 byte

    movzx rcx, byte [rbx+38] ; green_mask_shift
    mov [framebuffer_struct_green_mask_shift], cl

    ; blue
    movzx rcx, byte [rbx+39] ; blue_mask_size
    ; byte, is well, 1 byte (8-bits).
    mov [framebuffer_struct_blue_mask_size], cl ; cl holds exactly 1 byte

    movzx rcx, byte [rbx+40] ; blue_mask_shift
    mov [framebuffer_struct_blue_mask_shift], cl

    ret

sys_query_limine_bootloader_info:
    ; since we are not working with the linux kernel here, we have total freedom of registers for pointer chasing.
    mov rax, [bootloader_info_request + 40] ; we need the response field, which is at the 40th offset of bootloader_info_request.
    test rax, rax
    jz no_response
    ; rax now has the response pointer.
    ; to extract data from the response, we need to chase the pointer offsets for the response.
    ; limine's bootloader response struct (in C, is like this)
    ; struct limine_bootloader_info_response {
    ;     uint64_t revision; // +0
    ;     LIMINE_PTR(char *) name; // +8
    ;     LIMINE_PTR(char *) version; // +16
    ; };
    ; using the same pointer chasing model here, we can track down the "name" field, at the 8th offset.
    mov rbx, [rax+8] ; now rbx has the name field's pointer.
    mov rcx, [rax+0] ; revision
    mov rdx, [rax+16] ; version

    ; move to .bss scratch variables, and then free up the registers
    mov [bootloader_name], rbx
    mov [bootloader_version], rdx
    mov [bootloader_revision], rcx

    ret

sys_delay:
    ; sys_delay(input time in seconds)
    ; input time in seconds
    ; rbx = seconds
    ; the algorithm will be as such:
    ; current_ticks = timer_ticks (defined in .data and updated by the timer)
    ; target_ticks = current_ticks + ((input time in seconds) * (ticks_per_seconds))
    ;
    ; while current_ticks < target_ticks:
    ;    wait
    mov rdx, rbx ; copy requested seconds into rdx
    mov rcx, [rel timer_ticks]
    imul rdx, TIMER_TICKS_PER_SEC
    add rdx, rcx ; target_ticks
    jmp .loop_sys_delay

.loop_sys_delay:
    mov rcx, [rel timer_ticks]
    cmp rcx, rdx
    jl .loop_sys_delay

.done_sys_delay:
    ret

setup_legacy_PIT:
    ; desired input frequency for the PIT has been fixed to be 100hz.
    ; not changing this.

    ; The hardware path of getting an interrupt to the CPU is as follows:
    ; PIT --> IRQ0 --> PIC --> Interrupt vector --> CPU --> IDT --> timer handler

    ; The PIT, Programmable interrupt timer, takes in a specifc request format
    ; It takes in a 1 byte instruction, where a certain number of bits denote different aspects of the request
    ; The bits are read and arranged backwards
    ; bits 7 and 6 : PIT channel number.
    ; bits 5 and 4 : Tell PIT counter how data will be supplied
    ; bits 3, 2 and 1 : PIT timer operating mode
    ; bit 0: Binary vs BCD counting

    ; acceptable values per bit range:
    ; bits: 7 to 6: PIT Channel number
    ;    00 : Channel 0
    ;    01 : Channel 1
    ;    10 : Channel 2
    ;    11 : read-back mode
    ;
    ; bits 5 to 4: Access Mode
    ;   00 = Latch count value (for reading back current timer state)
    ;   01 = Access low byte only (Bits 0-7)
    ;   10 = Access high byte only (Bits 8-15)
    ;   11 = Access low byte first, then high byte (Standard 16-bit payload)
    ;
    ; bits 3, 2 and 1: Operating Mode
    ;   000 = Mode 0: Interrupt on terminal count (Good for one-shot delays)
    ;   001 = Mode 1: Hardware re-triggerable one-shot
    ;   010 = Mode 2: Rate generator (Generates cyclic periodic interrupts) -> Best for OS multitasking!
    ;   011 = Mode 3: Square wave generator (Used for PC speaker tones)
    ;   100 = Mode 4: Software triggered strobe
    ;   101 = Mode 5: Hardware triggered strobe
    ;   Note: 'x' can be 0 or 1; standard practice uses 010 and 011.
    ;
    ; bit 0: Counting Mode
    ;   0 = Binary counter (16-bit, standard for x86)
    ;   1 = BCD counter (Binary Coded Decimal, 4 decades)

    ; Since we want to use channel 1, that's
    ; 00
    ; want to send both low and high bytes, as our divisor is 16-bit
    ; 11
    ; Need a square wave generator for a steady source of interrupts
    ; 011
    ; Need a binary counter
    ; 0
    ; That makes the request value: 00110110
    ; The hexadecimal equivalent is 36, or 0x36
    ; The request size is 8 bits, or 1 byte, so we will use the al register
    mov al, 0x36
    ; The PIT has specific ports, each have a following function
    ; 0x40: (3x4+0 = 12), port 12, which handles channel 0 data
    ; 0x41: port 13, which handles channel 1 data
    ; 0x42: port 14, which handles channel 2 data
    ; 0x43: port 15, which is the command / mode register
    ; since we setting the mode of the PIT, we will use the 0x43 port
    ; this is done using the out operation
    out 0x43, al

    ; the calculation for the divisor we want is given by
    ;
    ;                  PIT base frequency
    ;  PIT divisor = -----------------------
    ;                  desired frequency
    ;
    ;
    ; Since we wish to achieve an output frequency of 100hz
    ;
    ;
    ;                     1193182 (PIT base frequency) (defined in .rodata as PIT_FREQUENCY)
    ; PIT divisor = ------------------------------------------------------------------------
    ;                     100
    ;
    ; PIT divisor = 11931
    ;
    ; as this is a 16-bit divisor, we need the 16-bit register

    mov ax, PIT_DIVISOR ; 16-bit value

    ; we need the quotient
    ; send low byte first
    out 0x40, al
    ; send high byte next
    ; out cannot accept ah, so:
    shr eax, 8 ; we shift the low byte out and the high byte in
    out 0x40, al

    ret

setup_legacy_8259_PIC:
    ; now we move to the PIC, The Programmable Interrupt Controller
    ; ============================================================
    ; 8259 Programmable Interrupt Controller (PIC)
    ; ============================================================
    ;
    ; The legacy x86 PIC consists of two 8259-compatible controllers:
    ;
    ;   Master PIC
    ;       Command port = 0x20
    ;       Data port    = 0x21
    ;
    ;   Slave PIC
    ;       Command port = 0xA0
    ;       Data port    = 0xA1
    ;
    ; The master handles IRQ0-IRQ7.
    ; The slave handles IRQ8-IRQ15.
    ;
    ; The slave is connected to IRQ2 of the master.
    ;
    ; For Orion's PIT timer:
    ;
    ;   PIT Channel 0
    ;        |
    ;        | IRQ0
    ;        V
    ;   Master PIC
    ;        |
    ;        | interrupt vector
    ;        V
    ;       CPU
    ;        |
    ;        V
    ;       IDT
    ;
    ; ============================================================
    ; PIC Initialization Command Words
    ; ============================================================
    ;
    ; The PIC is initialized by sending ICW1, ICW2, ICW3 and
    ; optionally ICW4 to its command/data ports.
    ;
    ; ICW1 -> sent to command port
    ; ICW2 -> sent to data port
    ; ICW3 -> sent to data port
    ; ICW4 -> sent to data port
    ;
    ; The PIC determines whether ICW4 is required from ICW1.
    ;
    ;
    ; ------------------------------------------------------------
    ; ICW1
    ; ------------------------------------------------------------
    ;
    ; Bit:  7 6 5 4 3 2 1 0
    ;       x x x 1 x x x x
    ;
    ; Bit 0: IC4
    ;
    ;   0 = ICW4 is not required
    ;   1 = ICW4 is required
    ;
    ; Bit 1: SNGL
    ;
    ;   0 = Cascade mode
    ;   1 = Single PIC
    ;
    ; Bit 2: ADI
    ;
    ;   0 = Call address interval = 8
    ;   1 = Call address interval = 4
    ;
    ; Bit 3: LTIM
    ;
    ;   0 = Edge triggered
    ;   1 = Level triggered
    ;
    ; Bits 4:5
    ;
    ;   Bit 4 must be 1 to identify this as ICW1.
    ;   Other bits are reserved / implementation-defined.
    ;
    ; Bits 6:7
    ;
    ;   Reserved.
    ;
    ;
    ; For a normal PC-compatible x86 setup:
    ;
    ;   ICW1 = 00010001b = 0x11
    ;
    ; This means:
    ;
    ;   ICW4 required
    ;   cascade mode
    ;   edge-triggered interrupts
    ;
    ;
    ; ------------------------------------------------------------
    ; ICW2
    ; ------------------------------------------------------------
    ;
    ; ICW2 specifies the BASE interrupt vector for the PIC.
    ;
    ; For the master PIC:
    ;
    ;   IRQ0 -> base + 0
    ;   IRQ1 -> base + 1
    ;   IRQ2 -> base + 2
    ;   ...
    ;   IRQ7 -> base + 7
    ;
    ; For Orion we normally remap the master PIC to:
    ;
    ;   base = 0x20
    ;
    ; Therefore:
    ;
    ;   IRQ0 -> interrupt vector 0x20
    ;   IRQ1 -> interrupt vector 0x21
    ;   IRQ2 -> interrupt vector 0x22
    ;   ...
    ;   IRQ7 -> interrupt vector 0x27
    ;
    ; The reason for remapping is that the original legacy PIC
    ; vectors overlap with CPU exception vectors in protected/long
    ; mode.
    ;
    ;
    ; ------------------------------------------------------------
    ; ICW3
    ; ------------------------------------------------------------
    ;
    ; ICW3 describes how the two PICs are connected.
    ;
    ; For the MASTER PIC:
    ;
    ;   Each bit corresponds to an IRQ input.
    ;
    ;   bit 0 -> IRQ0
    ;   bit 1 -> IRQ1
    ;   bit 2 -> IRQ2
    ;   ...
    ;   bit 7 -> IRQ7
    ;
    ;   A bit set to 1 means a slave PIC is connected to
    ;   that IRQ line.
    ;
    ; The slave PIC is connected to IRQ2:
    ;
    ;   00000100b = 0x04
    ;
    ; For the SLAVE PIC:
    ;
    ;   Bits 2:0 specify which master's IRQ line the slave
    ;   is connected to.
    ;
    ; Since the slave is connected to master IRQ2:
    ;
    ;   00000010b = 0x02
    ;
    ;
    ; Therefore:
    ;
    ;   Master ICW3 = 0x04
    ;   Slave  ICW3 = 0x02
    ;
    ;
    ; ------------------------------------------------------------
    ; ICW4
    ; ------------------------------------------------------------
    ;
    ; ICW4 controls the PIC's operating mode.
    ;
    ; Bit:  7 6 5 4 3 2 1 0
    ;       x x x x x x x x
    ;
    ; Bit 0: 8086/88 mode
    ;
    ;   0 = MCS-80/85 mode
    ;   1 = 8086/88 mode
    ;
    ; Bit 1: AEOI
    ;
    ;   0 = Normal End Of Interrupt
    ;   1 = Automatic End Of Interrupt
    ;
    ; Bit 2: M/S
    ;
    ;   Only meaningful when BUF = 1.
    ;
    ; Bit 3: BUF
    ;
    ;   0 = Non-buffered mode
    ;   1 = Buffered mode
    ;
    ; Bit 4: SFNM
    ;
    ;   0 = Special Fully Nested Mode disabled
    ;   1 = Special Fully Nested Mode enabled
    ;
    ; For a normal x86 protected/long-mode setup:
    ;
    ;   ICW4 = 00000001b = 0x01
    ;
    ; This selects 8086/88 mode.
    ;
    ;
    ; ============================================================
    ; PIC Operational Command Words
    ; ============================================================
    ;
    ; After initialization, the PIC can receive operational
    ; commands.
    ;
    ; The most important one for Orion initially is the EOI
    ; (End Of Interrupt) command.
    ;
    ; After servicing a hardware interrupt, the interrupt handler
    ; must tell the PIC that the interrupt has been handled.
    ;
    ; For an IRQ originating on the MASTER PIC:
    ;
    ;   mov al, 0x20
    ;   out 0x20, al
    ;
    ; 0x20 is the Non-Specific EOI command.
    ;
    ; For an IRQ originating on the SLAVE PIC, an EOI must normally
    ; be sent to both:
    ;
    ;   out 0xA0, al    ; slave
    ;   out 0x20, al    ; master
    ;
    ; ===========================================================

    ; First half of the process
    ; We need to prepare the PIC to receive the IRQ0 from the PIT
    ; So, we need to start with ICW1
    ; For a standard x86 PC interrupt stuff
    ; We need an ICW1 request that tells:
    ; It's an ICW4 (Bit 0): 1
    ; It's in cascade mode (Bit 1): 0
    ; It has a call address interval of 8 (Bit 2): 0
    ; It's edge triggered (Bit 3): 0
    ; It IS an ICW1 request (bit 4 must be 1): 1
    ; Rest are reserved bits to set to 0 (bits 5, 6 and 7)
    ; This gives us: 00010001 -> or 0x11 -> 8 bits, 1 byte
    ; The addresses of the two PIC controllers are:
    ;   Master PIC
    ;       Command port = 0x20
    ;       Data port    = 0x21
    ;
    ;   Slave PIC
    ;       Command port = 0xA0
    ;       Data port    = 0xA1

    ; We need to initialize BOTH the master and slave PIC controllers
    ; Master PIC ICW1 initialization
    mov al, 0x11
    out 0x20, al

    ; Slave PIC ICW1 initialization
    mov al, 0x11
    out 0xA0, al

    ; onwards to ICW2 now.
    ; ICW2 specifies the BASE interrupt vector for the PIC
    ; The BASE is configuration value stored inside the PIC that, when added to an IRQ number
    ; results in the interrupt vector address translated for the CPU to use.
    ; So:
    ; IRQ0 = base + 0
    ; IRQ1 = base + 1
    ; IRQ2 = base + 2
    ; .....
    ; For the Orion kernel, we will remap the base of the master PIC to 0x20 to prevent it from clashing with
    ; CPU exception vectors as we are booting 64-bit long mode.
    ; So for us:
    ; IRQ0 = 0x20 + 0 = 0x20
    ; This value will go into the data port of the master PIC controller
    mov al, 0x20
    out 0x21, al

    ; onwards to ICW3 now.
    ; ICW3 is just...weird.
    ; Because irrespective of the IRQ number, we have to tell the master PIC controller
    ; that it has a slave PIC controller attached to via the line used for handling IRQ2.
    ; The request is as follows
    ; it's a 1 byte request, where bits 0 to 7 are IRQ0 to IRQ7 respectively on the master PIC
    ; and bits 0 to 7 on the slave PIC line handle IRQ 8 to IRQ 15.
    ; For IRQ0 we don't need anything else save just tell the master PIC that it has a slave PIC
    ; attached to it via the IRQ2 line
    ; so the ICW3 request becomes 00000100 or 4 in hexadecimal, or 0x04

    mov al, 0x04
    out 0x21, al ; into the data port of the master PIC

    ; onwards to ICW4, the operating mode of the PIC.
    ; This is again a 1 byte request with bits from 0 to 7 having different values
    ; for a standard x86 pc all we need is it to be operating in the 8086/88 mode, which is set by
    ; setting bit 0 to 1.
    ; so the ICW4 request becomes: 00000001 or 1 or 0x01
    ; This request is to be sent to both the master and the slave PIC controllers

    mov al, 0x01,
    out 0x21, al ; once to the master PIC

    mov al, 0x01
    out 0xA1, al ; again to the slave PIC

    ; next up is configuring the Interrupt Mask Register (IMR)
    ; The IMR is the register that will allow the IRQ0 through
    ; For the master PIC, the IMR is it's data port after initialization
    ; which takes 1 byte request, where if bit 0 is:
    ; 0: then IRQ is enabled
    ; 1: then IRQ is masked
    ; so to allow the IRQ0 through we need to set the LSB to 0
    ; and all the other bits to 1 since we are we not using those IRQs
    ; so the request ends up being: 11111110 or 254 or FE_16
    ; so we will push 0xFE
    mov al, 0xFE
    out 0x21, al

    ret

setup_IDT:
    ; now we have to interact with the IDT which the CPU uses to convert the interrupt vector
    ; to an IDT request, so we need to map that to a timer interrupt handler method
    ; this timer interrupt handler will call actual code to wake up the CPU from a halted state.
    ; now that the timer interrupt handler subroutine has been defined
    ; we will not call it yet
    ; since our CPU doesn't yet know where to send that interrupt request
    ; so call .timer_interrupt_handler won't work.
    ; we need to configure the IDT next and then map an interrupt vector
    ; to the address of the timer interrupt handler subroutine

    ; The IDT (Interrupt Descriptor Table) is a table in memory holding 256 (0-255) entries
    ; The CPU uses this table as an index and does
    ; IDT + (interrupt_vector × size_of_IDT_entry)
    ; To get the effective address where execution must be transferred

    ; now to do this, we need to build the IDT descriptor first to tell the CPU:
    ; to tell the CPU where the IDT is and how large it is.
    ; but we have run into a dependency, since the IDT gate contains a field called
    ; Segment selector: which looks for code segment to execute when entering the timer interrupt
    ; handler method.
    ; For this, we need to build a GDT first. Orion doesn't have any at the moment.
    ; GDT has been built and is operational.
    ; The IDT has also been described now.
    ; Now we will construct just one gate, the timer gate of the IDT.
    ; The gate is 16-bytes (128-bits)
    ; 127                         96 95                         64
    ; ┌----------------------------─┬─---------------------------─┐
    ; |        Reserved             |       Offset 63:32          |
    ; └----------------------------─┴─---------------------------─┘
    ;
    ; 63                          48 47   46  45  44    40 39      32
    ; ┌-----------------------------┬---┬-----┬---┬------┬----------┐
    ; |      Offset 31:16           │ P | DPL | 0 | Type |    IST   |
    ; └-----------------------------┴---┴-----┴---┴------┴----------┘
    ;
    ; 31                          16 15                           0
    ; ┌-----------------------------┬-----------------------------┐
    ; |      Segment Selector       |        Offset 15:0          |
    ; └-----------------------------┴-----------------------------┘
    ;
    ; Let's understand what each field means so that we can construct the
    ; timer gate magic number from first principles without it feeling like some
    ; dark magic
    ;
    ; Bits 39 to 32
    ;
    ;  39        32
    ; ┌-----┬-----┐
    ; | Res.| IST |
    ; └-----┴-----┘
    ;
    ; bits 35 to 39 = reserved
    ;
    ; Bits 0 to 15: offset
    ;
    ; These are the lower 16 bits of the intterupt handler address
    ; The upper bits lie between bits 48 to 63:
    ;
    ; For example purposes, say the address of .timer_interrupt_handler was:
    ;  0xFFFFFFFF80002000
    ;
    ; Then: bits 63 to 48 = 0xFFFFFFFF80002000
    ; while lower 16 bits, bits 15 to 0: 0x2000
    ;
    ; Bits 16 to 31: The segment selector:
    ;
    ; This is the part of the IDT that connects to the GDT
    ;
    ; Since we will be entering Orion's kernel segment, it's at GDT entry 1:
    ;
    ; 1 x 8 bytes = 0x08
    ;
    ; so bits 31-16 would be 0x08
    ;
    ; Bits 34-32: The IST, Intterupt Stack Table
    ;
    ; It's 3 bits wide:
    ;
    ; 000 = IST disabled
    ; 001 = IST 1
    ; 002 = IST 2
    ; ....
    ;
    ; A value of 0 will tell the CPU to NOT switch to an IST stack, so the CPU will use
    ; normal interrupt-stack rules.
    ;
    ; A non-zero value of this will tell the CPU to switch to the corresponding stack defined by the
    ; Task State Segment (TSS)
    ;
    ; But since Orion doesn't have a TSS/IST (yet, but it will, soon)
    ;
    ; For we now, we keep bits 34-32 = 000.
    ;
    ; Bits 39 to 35, reserved. We cannot assign anything there
    ;
    ; So, for our gate: 00000.
    ;
    ; Bits 43 to 40: Gate Type
    ;
    ; There are two relevant gate types:
    ;
    ; 1. 1110: 0xFE --> 64-bit interrupt gate
    ; 2. 1111: 0xF --> 64-bit trap gate
    ;
    ; An interrupt gate causes the CPU to clear the IF flag when it enters the interrupt handler
    ; A trap gate doesn't clear the IF flag. Historically the trap gate was used for legacy linux syscalls for say I/O stuff like reading a file
    ; Trap gates are still used in modern OSes and kernels but for stuff like debugging breakpoints
    ; or to bypass arithmetic errors like divide-by-zero exception or overflow exceptions.
    ;
    ; For our purpose we will need the interrupt gate
    ;
    ; So bits 43-40 will be 1110 --> 0xE.
    ;
    ; Bit 44: Reserved i.e. bit 44 = 0.
    ;
    ; Bits 46-45: DPL, Descriptor Privilege Level.
    ;
    ; It's 2 bits:
    ;
    ;  46 45
    ; ┌--┬--┐
    ; |D1|D0|
    ; └--┴--┘
    ;
    ; giving:
    ;
    ; 00 --> Ring 0
    ; 01 --> Ring 1
    ; 10 --> Ring 2
    ; 11 --> Ring 3
    ;
    ; But this DPL is different from that of the GDT.
    ;
    ; The IDT gate's DPL controls which privilege level is allowed to invoke the
    ; gate using a software interrupt instruction such as INT n.
    ;
    ; For example if the IDT's DPL = 00
    ;
    ; Then ring 3 code simply cannot do:
    ;
    ; int 0x20 and then use that gate to enter the kernel.
    ;
    ; But a hardware IRQ doesn't care about this DPL in the same way. The hardware interrupt can still
    ; enter the gate.
    ;
    ; However we will keep DPL = 00, since we don't want ring 3 code to reach our timer gate.
    ;
    ; Thus bits 46-45 = 00.
    ;
    ; Bit 47 --> Present bit(P): states if the IDT is present and usable or not.
    ;
    ; For our time gate:
    ; bit 47 = 1.
    ;
    ; Bits 63-48: as already stated earlier, another 16 bits of the handler address.
    ;
    ; These combined with bits 0-15 form the lower 32-bits of the handler address
    ;
    ; Bits 95-64: the remaining, upper 32-bits of the handler address.
    ;
    ; Lastly, bits 127-96: Reserved, all zero for our gate.
    ;
    ; Now then, let's construct the binary equivalent first before getting the hexadecimal
    ; magic number for the gate.
    ;
    ; Bits: 127 to 96
    ; 00000000000000000000000000000000 -> 0x0
    ;
    ; bits 95 to 48 all handler address, we can't populate at this comment writing stage.
    ; bit 47 = 1
    ; bits 46-45 = 00 -> 0x0
    ; bit 44, reserved = 0 --> 0x0
    ; bits 43-40, gate type = 1110 (0xE), interrupt gate.
    ; bits 39 to 35, reserved = 00000 --> 0x0
    ; bits 34 to 32, IST, currently: 000 --> 0x0
    ; bits 31 to 16, segment selector, we need: 0x08 (1000 in binary)
    ; bits 15 to 0: handler address, unknown at this stage.

    ; so now we calculate and load the effective address of .timer_interrupt_handler

    lea rax, [rel .timer_interrupt_handler]

    ; this gives us: rax = 0xffffffff80001383 (discovered from the gdb trace)
    ; This address is will stay the same for now since:
    ; And unlike something such as a runtime heap address,
    ; this address will normally remain the same across runs of the same kernel binary.
    ; The kernel isn't using ASLR/KASLR at this stage, so the linker has placed the
    ; function at a deterministic virtual address. It can change if I later, change
    ; the binary's layout, add/remove code, change the linker script, etc.
    ;
    ; However since I don't want to hardcode that address, we will instead mathematically
    ; split rax into 3 16-bit pieces then mathematically construct the IDT gate magic number.
    ;
    ; let's extract the lowest 16 bits from rax first, i.e bits 15 to 0

    ; first we store the original address in rdi
    mov rdi, rax
    mov bx, ax ; bx now has bits 15 to 0.

    ; next we need the next 16 bits, for bits 63 to 48.
    ; so we shift out the lowest 16 bits which we don't need now.

    shr rax, 16
    mov cx, ax ; now we have bits 63 to 48 to in cx

    ; now rax has the remaining upper 32 bits that would fill up bits 95 to 64.
    ; we would query eax to get those 32 bits.

    ; now we gotta pack them bits into one single magic number.
    ;
    ; currently our magic numbers is:
    ;
    ; 00000000000000000000000000000000<-bits 95 to 48 (32 bit) gap-->10001110000000001000<--remaining 16 bits of the handler address-->
    ; leaving aside the handler address bits, this would be our magic number's constant parts every time for this IDT's IRQ0 timer intterupt gate initialization.
    ; for the discovered hex address of .timer_interrupt_handler, the binary equivalent is:
    ; 1111111111111111111111111111111110000000000000000001001110000011
    ;
    ; lower 16 bits, (bits 15-0): 0001001110000011
    ; next 16 bits (bits 63-48): 1000000000000000
    ; remaining upper 32 bits (bits 95-64): 11111111111111111111111111111111

    ; so our final magic number, for this address would look like:
    ; 00000000000000000000000000000000111111111111111111111111111111111000000000000000100011100000000010000001001110000011
    ; or FFFFFFFF80008E0081383 in hexadecimal
    ; or 0x00000000FFFFFFFF80008E0000081383.
    ;
    ; however we are not going to assume that the handler address will never change in future, so we will not hardcode this number.

    ; BX  = handler bits 15:0
    ; CX  = handler bits 31:16
    ; EAX = handler bits 63:32

    ; -------------------------
    ; Construct low 64 bits
    ; -------------------------

    movzx rbx, bx              ; zero extend the bits up to 64 bits.

    movzx rcx, cx
    shl rcx, 48                ; bits 63:48
    or rbx, rcx                ; we already know from earlier back in sys_plot_pixel that this is a bitwise OR.

    mov rcx, 0x08              ; our kernel code descriptor address.
    shl rcx, 16                ; segment selector --> bits 31:16
    or rbx, rcx

    mov rcx, 0x8E
    shl rcx, 40                ; gate attributes --> bits 47:40
    or rbx, rcx

    ; -------------------------
    ; Construct high 64 bits
    ; -------------------------

    mov edx, eax               ; handler bits 63:32 -> gate bits 95:64

    ; bits 127:96 remain zero
    ; so for our current handler address:
    ; rbx = 0x80008E0000081383
    ; rdx = 0x00000000FFFFFFFF

    ; now we can actually put the gate into the IDT:
    ; let me do a quick gdb test run before this.
    ; (gdb) orion-dump regs
    ; -- registers --
    ;   rax    = 0x0000ffffffff8000
    ;  rbx    = 0x80008e00000813bd
    ;  rcx    = 0x00008e0000000000
    ;  rdx    = 0x00000000ffff8000
    ;  rsi    = 0x0000000000000000
    ;  rdi    = 0xffffffff800013bd
    ;  rbp    = 0x0000000000000000
    ;  rsp    = 0xffff800007f95ff0
    ;  r8     = 0x0000000000000000
    ;  r9     = 0x0000000000000000
    ;  r10    = 0x0000000000000000
    ;  r11    = 0x0000000000000000
    ;  r12    = 0x0000000000000000
    ;  r13    = 0x0000000000000000
    ;  r14    = 0x0000000000000000
    ;  r15    = 0x0000000000000000
    ;  ax     = 0xffffffffffff8000
    ;  al     = 0x0000000000000000
    ;  bx     = 0x00000000000013bd
    ;  bl     = 0xffffffffffffffbd
    ;  dx     = 0xffffffffffff8000
    ;  dl     = 0x0000000000000000
    ;  cx     = 0x0000000000000000
    ;  cl     = 0x0000000000000000
    ; cs     = 0x0000000000000008
    ;  ds     = 0x0000000000000010
    ;  es     = 0x0000000000000010
    ;  ss     = 0x0000000000000010

    ; the gdb dump shows us that:
    ; rbx and rdx are just as what we expected.
    ; so our 128-bit IDT entry magic number is split between two 64 bit halves.
    ; the upper 32-bit half of the handler address can be derived from :
    mov rdx, rdi
    shr rdx, 32

    ; gdb should show :
    ; rdx = 0x00000000ffffffff
    ; and yep, the gdb trace shows
    ; 0xffffffff800013c3 in setup_hardware ()
    ; (gdb) orion-dump regs
    ; -- registers --
    ;   rax    = 0x0000ffffffff8000
    ;   rbx    = 0x80008e00000813c4
    ;   rcx    = 0x00008e0000000000
    ;   rdx    = 0x00000000ffffffff
    ;   rsi    = 0x0000000000000000
    ;   rdi    = 0xffffffff800013c4
    ;   rbp    = 0x0000000000000000
    ;   rsp    = 0xffff800007f95ff0
    ;   r8     = 0x0000000000000000
    ;   r9     = 0x0000000000000000
    ;   r10    = 0x0000000000000000
    ;   r11    = 0x0000000000000000
    ;   r12    = 0x0000000000000000
    ;   r13    = 0x0000000000000000
    ;   r14    = 0x0000000000000000
    ;   r15    = 0x0000000000000000
    ;   ax     = 0xffffffffffff8000
    ;   al     = 0x0000000000000000
    ;   bx     = 0x00000000000013c4
    ;   bl     = 0xffffffffffffffc4
    ;   dx     = 0xffffffffffffffff
    ;   dl     = 0xffffffffffffffff
    ;   cx     = 0x0000000000000000
    ;   cl     = 0x0000000000000000
    ;   cs     = 0x0000000000000008
    ;   ds     = 0x0000000000000010
    ;   es     = 0x0000000000000010
    ;   ss     = 0x0000000000000010

    ; So the complete gate is:
    ; HIGH 64 bits
    ; 0x00000000FFFFFFFF
    ;
    ; LOW 64 bits
    ; 0x80008E00000813C4

    ; or, laid out as the 16-byte gate:
    ; +----------------------+----------------------+
    ; | 0x00000000FFFFFFFF   | 0x80008E00000813C4   |
    ; +----------------------+----------------------+
    ;         high qword              low qword

    ; now we can safely write the gate into the IDT

    mov [idt + 0x200], rbx ; lower 64 bits
    mov [idt + 0x208], rdx ; upper 64 bits

    ; now we tell the CPU where to look for the IDT descriptor via lidt

    lidt [idt_descriptor]

    ret

.timer_interrupt_handler:
    ; timer tick occurred
    ; we need to tell the master PIC that an interrupt has been handled
    ; and that it may receive another one
    ; we do that by sending an EOI --> End Of Interrupt signal to the master PIC
    ; The EOI signal is 0x20.
    ; however this signal must be sent to the command port of the master PIC
    ; as writing 0x20 to the data port will modify the IMR instead.

    ; this will tell sys_delay that yes, a timer tick has occurred.
    push rax ; save rax to stack, since it gets clobbered later
    inc qword [rel timer_ticks] ; increment the timer tick variable by 1
    mov al, 0x20
    out 0x20, al
    ; retrive rax from stack
    pop rax

    iretq ; we use iretq since the CPU pushes it's own interrupt-return state onto the stack
            ; and the when the interrupt arrives iretq restores the state.

setup_legacy_hardware:

    ; ========Setup of legacy PIT, legacy PIC, and IDT for getting a timer interrupt.========
    ; setup the PIT
    call setup_legacy_PIT

    ; setup legacy PIC
    call setup_legacy_8259_PIC

    ; ========End Setup of legacy PIT, legacy PIC, and IDT for getting a timer interrupt.========

    ret

setup_tss_descriptor:

    ; construction of the TSS descriptor
    ;
    ; The TSS descriptor is a 128-bit descriptor where each bit region has it's own designation
    ;
    ;
    ;
    ;   TSS DESCRIPTOR -- 128 bits
    ;
    ;    127                                      96
    ;    ┌----------------------------------------┐
    ;    │              RESERVED = 0              │
    ;    └----------------------------------------┘
    ;
    ;    63       56 55 54 53 52 51    48 47 46 45 44 43    40 39       32 31     24 23    16 15        0
    ;    ┌----------┬-┬-┬-┬---┬----------┬-┬----┬----┬--------┬----------┬----------┬----------┬------------┐
    ;    |BASE31:24 |G│D│L│AVL│LIM19:16  │P│DPL │ S  │ TYPE   │BASE23:16 │BASE15:8  │BASE7:0   │ LIMIT15:0  │
    ;    └----------┴-┴-┴-┴---┴----------┴-┴----┴----┴--------┴----------┴----------┴----------┴------------┘
    ;
    ;   Notice how the flags are similar to that of the GDT.
    ;
    ;   But this time some of the flags have different implications than in the case of GDT.
    ;
    ;   Type = 1001 ; 64-bit available TSS
    ;   Type = 1011 ; 64-bit busy TSS
    ;
    ;   We will initialize the Type bits as 1001 by default.
    ;
    ;   These 4 bits are automatically set by the CPU as per the availablility of the TSS.
    ;
    ;   S bit, same as GDT.
    ;   S = 0 --> system descriptor
    ;   S = 1 --> code/data descriptor
    ;
    ;   Since this is not a code segment, thus S = 0.
    ;
    ;   DPL --> Descriptor privilege bits, same as GDT
    ;   DPL = 00, ring 0, DPL = 11, ring 3, that's all we need for now.
    ;   DPL will be 00 here.
    ;
    ;   P, present bit --> denotes if the descriptor is present or not, if set to 0 then attempting to load the
    ;   descrptor with ltr will fault.
    ;   P will be 1 here.
    ;
    ;   G, granularity, set to 0 here since the TSS is only 104 bytes.
    ;
    ;   L, denotes if the descriptor is in 64-bit long mode, but since the TSS descriptor is not a code segment,
    ;   L = 0
    ;
    ;   D = 0, same story as L for the TSS descriptor.
    ;
    ;   AVL, availablility for software use, CPU doesn't need this, so we set it to 0.
    ;
    ;   so leaving out the base bits, which would the address of tss64, we have the limit bits as TSS_LIMIT.
    ;
    ;   and remaining bits 127 to 96 are reserved, thus set to 0.

    ; phase 1, we calculate tss64's address and split it's base bits accordingly for our descriptor
    ; The base bits are split across as follows:
    ;
    ; Let B = address of tss64
    ;
    ; | Descriptor bits | Base bits placed there |   Width |
    ; | --------------: | ---------------------: | ------: |
    ; |         23:16 |               B[7:0]     |  8 bits |
    ; |         31:24 |              B[15:8]     |  8 bits |
    ; |         39:32 |             B[23:16]     |  8 bits |
    ; |         63:56 |             B[31:24]     |  8 bits |
    ; |         95:64 |             B[63:32]     | 32 bits |

    ; rax has no need of holding the previous value at this point,

    lea rax, [rel tss64]
    movzx ebx, al ; store descriptor bits 23 to 16, while also zero extending them

    shr rax, 8 ; get these bits out of al now, since we don't neeed them.
    ; repeat again
    movzx ecx, al ; store descriptor bits 31 to 24, while also zero extending them

    shr rax, 8 ; get these bits out of al again.
    ; repeat again
    movzx edx, al ; store descriptor bits 39 to 32, while also zero extending them

    shr rax, 8 ; get these bits out of al again, while also zero extending them
    ; repeat again.
    movzx edi, al ; store descriptor bits 63 to 56, while also zero extending them

    shr rax, 8 ; get these bits out of al again.

    ; now eax should be holding the remaining 32-bit value of descriptor bits  95 to 64
    ; and we have all the base bits in 32-bit format, good.
    ; but we need to put these base bits in their correct order.
    ; for base bits 23 to 16,
    ; initially say:
    ; RBX = 00000000 00000000 00000000 10001000 (imaginary value, we are not sure if it's really 10001000, it's being used as an example)
    ;                                  B[7:0]
    ; We need that byte to occupy bits 23:16.
    ; So:
    shl rbx, 16
    ; produces:
    ; RBX = 00000000 00000000 10001000 00000000
    ;                         ↑
    ;                       23:16
    ; The lower 16 bits became zero.

    ; now similarly:

    shl rcx, 24 ; lower 24 bits become zero in rcx
    shl rdx, 32 ; lower 32 bits become zero in rdx
    shl rdi, 56 ; lower 56 bits become zero in rdi

    ; now as for the remaining base bits 63 to 32 in rax, we have a 32-bit value sitting in eax, so the upper half of rax is 0.
    ; but the descriptor's upper half wants this at 95:64.
    ; so no shifting here is required as this will become the descriptor's second 64-bit half.
    ; so we can just zero extend the value in rax so that it's upper 32-bit half is all zero.
    mov eax, eax
    ; now this is a query-able 64-bit value in rax which will form the lower 64-bit half of the total 128-bit TSS descriptor value.

    ; lastly, the limit
    ; this would be the address of the TSS_LIMIT from the tss.inc,
    ; and we have to compute and shift these to fit them in the same way.
    ; we have, bits 15 to 0 , that's 16 bits
    ; and bits 51 to 48 for the limit, that's 4 bits,
    ; 24 bits total, so we can store the value inside a 32-bit register.
    mov esi, TSS_LIMIT ; esi holds the value of the TSS_LIMIT.
    ; the lower 16 bits are exactly where we want them, no shift required for those.
    ; but we need to extract the upper 4 bits since those are needed in descriptor bits 51 to 48.
    ; so we can do this:
    mov r8d, esi ; r8d is the 32-bit portion register of the 64-bit r8 register
    shr r8d, 16 ; shift the lower 16 bits out.
    ; now we just need the 4 bits sitting at the very bottom of r8d, inside r8b.
    ; a not-so-clever-but-easy-to-understandable-way to proceed forward would be this:
    ; we shift the 4 bits we actually need to the upper half of r8b.
    shl r8b, 4
    ; now they are at the top of r8b.
    ; we can now take this same concept and move them up all the way so that they start from bit 48 and extend out to bit 51
    ; since we already shifted 4 bits out, all we need is the remaining 44 bits to be shifted.
    ; this shift operation will directly act on r8.
    shl r8, 44
    ; and now we have the remaining 4 limit bits exactly where we need them.

    ; now we construct the rest of the bits.
    ; bits 47 to 40:
    ; P DPL S TYPE
    ; 1 00  0 1001
    ; 10001001 --> 89 --> 0x89
    mov r9, 0x89
    ; shifting 0x89 all the way up so that they start at bit 40 and extend up to bit 47
    shl r9, 40

    ; bits 55, 54, 53, 52
    ; G, D, L, AVL
    ; 0, 0, 0, 0 (as discussed earlier)
    ; 0000 --> 0x0

    ; this would look something like:
    ; mov r10, 0x0
    ; shl r10, 52
    ; but then the register would be wasted since r10 is already zero at all bit places.

    ; bits 127 to 96, reserved, all zero.
    ; 00000000 00000000 00000000 00000000
    ; 0x0000000
    ; now what could be done for this?
    ; Well,
    ; since rax already contains:
    ;
    ;   descriptor bits 95:64  --> TSS base bits B[63:32]
    ;   descriptor bits 127:96 --> reserved = 0
    ;
    ; Therefore rax is already the complete upper 64-bit descriptor word.
    ; so, there's nothing further to be done here except to combine the remaining values to form the complete lower 64 bits of the TSS descriptor
    ; since rsi already has the TSS_LIMIT at the perfect range, we will be OR-ing everything else into rsi.

    or rsi, rbx
    or rsi, rcx
    or rsi, rdx
    or rsi, rdi
    or rsi, r8
    or rsi, r9

    ; so our entire tss descriptor is stored in two registers now.
    ; rax --> upper 64 bits of the TSS descriptor
    ; rsi --> lower 64 bits of the TSS descriptor.
    ; now we move these into our gdt's defined fields at the specific offsets

    mov qword [rel gdt + 0x28], rsi
    mov qword [rel gdt + 0x30], rax

    ; initialize the iomap_base
    mov word [rel tss64 + TSS_IOMAP_BASE], TSS_SIZE ; the iomap base's offset points beyond the end of the tss.

    mov ax, TSS_SELECTOR ; since ltr doesn't take an immediate offset constant, so we need 16-bit register/memory operand containing a selector.
    ltr ax ; tells the CPU to take 0x28, and then to interpret it as a selector for the task register, hence ltr.
    ; we need not load 0x30 since the CPU will already use this selector and access the upper 64-bit half of the TSS descriptor at 0x30

    ret

setup_kernel_stack:
    ; initialize the kernel stack pointer for CPU0
    lea rax, [rel kernel_stack0_top] ; load the address of the variable of kernel_stack0_top
    mov qword [rel tss64 + TSS_RSP0], rax ; store the address of tss64.rsp0 inside kernel_stack0_top

    ret

setup_hardware:
    ; one-time hardware components setup.

    ; setup legacy hardware (for now).
    call setup_legacy_hardware

    ; setup the IDT

    call setup_IDT

    ret

sys_exit:
    cli

.hang:
    hlt; halt the CPU until the next interrupt
    jmp .hang ; this throws the CPU into a hanged state if it wakes up from the halt for some reason.

no_response:
    jmp sys_exit

_start:

    ; Orion kernel initialization, load the gdt descriptor.
    ; the lgdt operation tells the CPU where to look for the GDT.
    lgdt [gdt_descriptor] ; very very important

    ; next up we need to load the kernel code segment and kernel data segment
    ; only the kernel code and data segment since we are in ring 0 for now
    ; we will load user code and data segment when we do a privilege transition later.

    ; so, the code segment lives in the cs register.
    ; but we cannot just do mov cs, 0x08 since the cs register is special
    ; so we use a far jump instead.
    ; The cs register is special because changing it is not merely changing where data
    ; accesses come from; it changes the CPU's current execution context.
    ; A far jump loads both:
    ; cs --> 0x08
    ; RIP --> address of .reload_cs (where then we will load the kernel data segment)
    ; into registers ds, es, and ss
    ; jmp 0x08:.reload_cs ; that's a far jump.
    ; oookayyy turns out that a far jump is NOT supported in 64-bit long mode.
    ; So we gotta take the long way here.

    ; load 0x08 onto cs
    push 0x08 ; at this point it's RSP --> 0x08
    ; calculate and load the effective address of .reload_cs onto rax
    lea rax, [rel .reload_cs] ; rel tells NASM to do rip relative addressing
    push rax ; push rax on the stack

    ; at this stage the stack is:
    ; 0x08
    ; rax ---> RIP
    ;
    ; Normally people like to visualize the stack bottom-up
    ; but stack actually growns downward.

    ; retf is far return.
    retfq ; far return in 64-bit mode

    ; performs:
    ; RIP --> RSP ; address of .reload_cs
    ; cs --> [RSP + 8] (0x08)

.reload_cs:
    ; Load Orion's kernel data segment
    mov ax, 0x10
    mov ds, ax
    mov es, ax
    mov ss, ax

    ; setup the hardware

    call setup_hardware

    ; initialize kernel timer state
    ; technically redundant since it's already defined in .data
    ; but I will keep the explicit initialization nonetheless.
    mov qword [rel timer_ticks], 0

    call setup_kernel_stack

    call setup_tss_descriptor

    sti ; set the interrupt flag
    ; now execution will happen in Orion's GDT, in ring 0.
    ; proceed as usual.
    jmp .kernel_main


.kernel_main:

    ; Orion's systemcalls

    ; query bootloader info
    mov rax, 0
    call syscall_dispatch

    ; query the framebuffer
    mov rax, 1
    call syscall_dispatch

    ; compute the coordinates of the center of the screen
    mov rax, 2
    mov rbx, orion_hello_message_length
    call syscall_dispatch

    ; print the hello message on the screen
    mov rax, 4
    mov rbx, orion_hello_message
    mov rcx, orion_hello_message_length
    mov rdx, [pen_x] ; computed from syscall 2
    mov rdi, [pen_y] ; computed from syscall 2
    mov rsi, -1 ; color mode, should default to white for now.
    call syscall_dispatch

    ; let's call a delay for 5 seconds.
    mov rax, 7
    mov rbx, 2
    call syscall_dispatch

    ; clear the screen
    mov rax, 6
    call syscall_dispatch

    ; let's call a delay for 2 seconds.
    mov rax, 7
    mov rbx, 5
    call syscall_dispatch

    ; re-compute the coordinates of the center of the screen
    mov rax, 2
    mov rbx, orion_hello_message_length
    call syscall_dispatch

    ; now let's print the creator name on the screen
    mov rax, 4
    mov rbx, orion_creator_name
    mov rcx, orion_creator_name_length
    mov rdx, [pen_x] ; computed from syscall 2
    mov rdi, [pen_y] ; computed from syscall 2
    mov rsi, 1 ; color mode, should default to white for now.
    call syscall_dispatch

    ; sys_exit
    mov rax, 5
    call syscall_dispatch
