OUTPUT_FORMAT("binary")
SECTIONS
{
  /* TODO: Figure out a way to update this address/value dynamically as it varies based on the size of the bootloader's 2nd stage. */
  /* . = 0x800a; */
  . = 0x8020;
  .text :
  {
    *(.text.kernel_main)
    *(.text)
  }
  .data :
  {
    *(.data)
  }
  .bss :
  {
    *(.bss)
  }
}
