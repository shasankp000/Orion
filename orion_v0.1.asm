default rel;

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

    ; now we end the request structure with the two LIMINE_REQUESTS_END_MARKER magic markers
    align 8
        dq 0xadc0e0531bb10d03
        dq 0x9572709f31764c62

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

    jmp sys_exit
