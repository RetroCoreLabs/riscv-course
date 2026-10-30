/* The lab program at the start of RAM, where the boot ROM jumps. The virtqueue and the
   request buffers follow it in .bss, each part on its own 4 KiB page. */
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
