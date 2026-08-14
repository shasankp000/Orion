OUTPUT_FORMAT(elf64-x86-64)

ENTRY(_start)

PHDRS
{
    limine_requests PT_LOAD;
    text            PT_LOAD;
    data            PT_LOAD;
}

SECTIONS
{
    /*
     * Place Orion in the upper half of the x86-64 address space.
     * This is the beginning of the topmost 2 GiB.
     */
    . = 0xffffffff80000000;

    /*
     * Limine request structures.
     */
    .limine_info_request :
    {
        KEEP(*(.limine_info_request))
    } :limine_requests

    /*
     * Code.
     */
    . = ALIGN(CONSTANT(MAXPAGESIZE));

    .text :
    {
        *(.text)
    } :text

    /*
     * Writable data.
     */
    . = ALIGN(CONSTANT(MAXPAGESIZE));

    .data :
    {
        *(.data)
    } :data

    /*
     * Uninitialised data.
     */
    .bss :
    {
        *(COMMON)
        *(.bss)
    } :data
}
