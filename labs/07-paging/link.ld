/* The lab program at the start of RAM, where the boot ROM jumps. Its data page and the
   three page tables follow it, each on its own 4 KiB page. */
OUTPUT_ARCH("riscv")
ENTRY(_start)
SECTIONS
{
    . = 0x80000000;
    .text : { *(.text.init) *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) }
    .bss : { *(.bss*) }
}
