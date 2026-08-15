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
    framebuffer_struct_green_mask_size resb 1 ; 1 byte only
    framebuffer_struct_green_mask_shift resb 1 ; 1 byte only

section .data

    ; "describe bytes", for NASM, gives us these 4 choices
    ; db    define byte       -> 8 bits
    ; dw    define word       -> 16 bits
    ; dd    define doubleword -> 32 bits
    ; dq    define quadword   -> 64 bits

    message db "Hello, from Orion!", 10
    length equ $ - message

section .text

    global _start



sys_exit:
    cli

.hang:
    hlt; halt the CPU until the next interrupt
    jmp .hang ; this throws the CPU into a hanged state if it wakes up from the halt for some reason.

no_response:
    jmp sys_exit

_start:
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

    ; now I am free to use the registers from rbx through rdx
    ; do I need to preserve rax as well, since I have effectively extracted what I need from the bootloader response?
    ; answer: nope, don't need that pointer anymore.

    ; so I can do this then?
    ; yep!
    mov rax, [frambuffer_request + 40] ; response field
    test rax, rax
    jz no_response
    mov rbx, [rax+0] ; revision
    mov rcx, [rax+8] ; number of framebuffers
    mov rdx, [rax+16] ; array of framebuffers

    mov [framebuffer_revision], rbx
    mov [framebuffer_count], rcx

    ; the framebuffer's struct address is at rdx ([rdx + 0])
    mov rbx, [rdx+0] ; move the actual struct to rbx
    ; now I can use an intermediate register + pointer hopping to get all the data I need

    mov rax, [rbx+0] ; address
    mov [framebuffer_struct_address], rax

    mov rax, [rbx+8] ; width
    mov [framebuffer_struct_width], rax

    mov rax, [rbx+16] ; height
    mov [framebuffer_struct_height], rax

    mov rax, [rbx+24] ; pitch
    mov [framebuffer_struct_pitch], rax

    movzx rax, word [rbx+32] ; bpp
    ; movzx is move with zero extend, fills out unnecessary bits with 0 instead of being stored as garabge values when moving a smaller value to a larger register
    ; it also needs a size operand since unlike plain mov, NASM cannot infer the source width from context, so it needs to know
    ; exactly how many bytes to zero extend from.
    ; word is 2 bytes
    mov [framebuffer_struct_bpp], ax ; ax holds exactly 2 bytes, not using rax here since we would then be writing extra garbage

    movzx rax, byte [rbx+37] ; green_mask_size
    ; byte, is well, 1 byte.
    mov [framebuffer_struct_green_mask_size], al ; al holds exactly 1 byte

    movzx rax, byte [rbx+38] ; green_mask_shift
    mov [framebuffer_struct_green_mask_shift], al

    jmp sys_exit
