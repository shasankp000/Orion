default rel;

%include "fonts/font8x8_basic.inc"

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

section .rodata

    ; "describe bytes", for NASM, gives us these 4 choices
    ; db    define byte       -> 8 bits
    ; dw    define word       -> 16 bits
    ; dd    define doubleword -> 32 bits
    ; dq    define quadword   -> 64 bits

    orion_hello_message db "Hello, from the Orion kernel!", 10
    orion_hello_message_length equ $ - orion_hello_message

    syscall_table:
        dq sys_query_limine_bootloader_info ; syscall 0
        dq sys_query_limine_framebuffer     ; syscall 1
        dq sys_get_center_of_screen         ; syscall 2
        dq sys_plot_pixel                   ; syscall 3
        dq sys_print_ASCII_string           ; syscall 4
        dq sys_exit                         ; syscall 5
        dq sys_clear_screen                 ; syscall 6

    syscall_table_end:
        %define SYSCALL_COUNT ((syscall_table_end - syscall_table) / 8)

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

sys_exit:
    cli

.hang:
    hlt; halt the CPU until the next interrupt
    jmp .hang ; this throws the CPU into a hanged state if it wakes up from the halt for some reason.

no_response:
    jmp sys_exit

_start:
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

    mov rax, 6
    call syscall_dispatch

    ; sys_exit
    mov rax, 5
    call syscall_dispatch
