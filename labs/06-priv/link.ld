/* The lab program at the start of RAM, where the boot ROM jumps. */
OUTPUT_ARCH("riscv")
ENTRY(_start)
SECTIONS
{
    . = 0x80000000;
    .text : { *(.text.init) *(.text*) }
    .rodata : { *(.rodata*) }
}
