ENTRY(start)
SECTIONS {
  /* Load address */
  . = 1M;
  .boot : {
    *(.multiboot)
  }
  .text { *(.text) }
  .data { *(.data) }
  .bss { *(.bss) }
}