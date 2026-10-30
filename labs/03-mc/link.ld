/* The lab program at the start of RAM, where the boot ROM jumps. The same script links the
   RV32 and the RV64 builds. The stack is 4 KiB after the program and grows down from
   _stack_top. */
OUTPUT_ARCH("riscv")
ENTRY(_start)
SECTIONS
{
    . = 0x80000000;
    .text : { *(.text.init) *(.text*) }
    .rodata : { *(.rodata*) }
    .data : { *(.data*) *(.sdata*) }
    .bss : { *(.bss*) *(.sbss*) *(COMMON) }
    . = ALIGN(16);
    . = . + 0x1000;
    _stack_top = .;
}
