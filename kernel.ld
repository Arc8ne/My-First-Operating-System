OUTPUT_FORMAT("binary");
SECTIONS
{
  . = 0x7e00;
  .text :
  {
    *(.text.kernel_main)
    *(.text)
  }
}
