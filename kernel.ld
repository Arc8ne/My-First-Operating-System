ENTRY(start)
SECTIONS {
  /* Load address */
  . = 1M;
  .boot : {
    *(.multiboot)
    *(.multiboot_2)
  }
  .text : { *(.text) }
  .data : { *(.data) }
  .bss : { *(.bss) }
}