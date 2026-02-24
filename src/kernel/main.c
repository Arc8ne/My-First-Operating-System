#include <stdint.h>
#include <stdbool.h>
#include <stdnoreturn.h>

#define VGA_TEXT_BUFFER_START_ADDRESS 0xb8000
#define NUM_BYTES_PER_ROW_IN_VGA_TEXT_BUFFER_IN_80x25_VIDEO_MODE 160
#define COM_1_BASE_PORT 0x3F8

extern void enable_paging(uint32_t* page_directory_physical_address);

// Note: Add `__attribute__((packed))` if this global variable is a struct.
__attribute__((aligned(4096)))
uint32_t page_directory[1024];
uint8_t* vga_text_buffer_current_address = (uint8_t*)VGA_TEXT_BUFFER_START_ADDRESS;

// --- Wrappers around the `outb` and `inb` Assembly instructions that allow the computer to perform I/O over ports ---
inline void outb(uint16_t port, uint8_t byte) {
  asm volatile ("outb %0, %1" : : "a"(val), "Nd"(port));
}

inline uint8_t inb(uint16_t port) {
  uint8_t byte;
  asm volatile("inb %0, %1" : : "Nd"(port), "a"(byte));
  return byte;
}
// --- End of section ---

void init_serial() {
  // Disable all interrupts.
  outb(0, COM_1_BASE_PORT + 1);
  // Enable DLAB (set baud rate divisor).
  outb(0x80, COM_1_BASE_PORT + 3);
  // Set divisor to 1 (lo byte) -> 115200 bps
  outb(0x1, COM_1_BASE_PORT);
  // (hi byte)
  outb(0, COM_1_BASE_PORT + 1);
  // 8 bits, no parity, one stop bit
  outb(0x3, COM_1_BASE_PORT + 3);
  // Enable FIFO, clear them, 14-byte threshold
  outb(0xc7, COM_1_BASE_PORT + 2);
  // Turn on DTR, RTS, and OUT2
  outb(0xb, COM_1_BASE_PORT + 4);
}

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

// TODO: Remove the dedicated bootloader's dependency on this attribute as it is not usually needed.
__attribute__((section(".text.kernel_main")))
extern void kernel_main(/* uint16_t vga_text_buffer_current_offset */) {
  // vga_text_buffer_current_address += vga_text_buffer_current_offset;
  // print("[Kernel] Started.\n");

  // enable_paging(page_directory);
}
