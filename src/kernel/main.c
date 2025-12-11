#include <stdint.h>
#include <stdbool.h>

#define VGA_TEXT_BUFFER_START_ADDRESS 0xb8000

void print_with_color(char* str_ptr, uint8_t color_code) {
  uint32_t i = 0;
  while (str_ptr[i] != 0) {
    char* current_char_address_in_vga_text_buffer = (char*)(VGA_TEXT_BUFFER_START_ADDRESS + i * 2);
    *current_char_address_in_vga_text_buffer = str_ptr[i];
    *(current_char_address_in_vga_text_buffer + 1) = color_code;
    i++;
  }
}

void print(char* str_ptr) {
  print_with_color(str_ptr, 0xf);
}

__attribute__((section(".text.kernel_main")))
extern void kernel_main() {
  print("Kernel loaded.");
  while (true) {}
}
