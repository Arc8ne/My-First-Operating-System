#include <stdint.h>
#include <stdbool.h>
#include <stdnoreturn.h>

#define VGA_TEXT_BUFFER_START_ADDRESS 0xb8000
#define NUM_BYTES_PER_ROW_IN_VGA_TEXT_BUFFER_IN_80x25_VIDEO_MODE 160

uint8_t* vga_text_buffer_current_address = (uint8_t*)VGA_TEXT_BUFFER_START_ADDRESS;

void print_with_color(char* str_ptr, uint8_t color_code) {
  uint16_t i = 0;
  while (true) {
    if (str_ptr[i] == 0) {
      break;
    }
    if (str_ptr[i] == '\n') {
      uint16_t vga_text_buffer_current_offset = (uint16_t)(vga_text_buffer_current_address - VGA_TEXT_BUFFER_START_ADDRESS);
      uint8_t vga_text_buffer_current_row_index = vga_text_buffer_current_offset % (NUM_BYTES_PER_ROW_IN_VGA_TEXT_BUFFER_IN_80x25_VIDEO_MODE - 1);
      uint8_t vga_text_buffer_next_row_index = vga_text_buffer_current_row_index + 1;
      uint16_t vga_text_buffer_next_line_offset = vga_text_buffer_next_row_index * NUM_BYTES_PER_ROW_IN_VGA_TEXT_BUFFER_IN_80x25_VIDEO_MODE;
    } else {
      *vga_text_buffer_current_address = str_ptr[i];
      vga_text_buffer_current_address += sizeof(uint8_t);
      *vga_text_buffer_current_address = color_code;
      vga_text_buffer_current_address += sizeof(uint8_t);
    }
    i++;
  }
}

void print(char* str_ptr) {
  print_with_color(str_ptr, 0xf);
}

__attribute__((section(".text.kernel_main")))
extern noreturn void kernel_main(uint16_t vga_text_buffer_current_offset) {
  vga_text_buffer_current_address += vga_text_buffer_current_offset;
  print("[Kernel] Started.\n");
  while (true) {}
}
