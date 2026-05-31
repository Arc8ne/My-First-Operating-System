#include <stdint.h>
#include <stdbool.h>
#include <stdnoreturn.h>

#define VGA_TEXT_BUFFER_START_ADDRESS 0xb8000
#define NUM_BYTES_PER_ROW_IN_VGA_TEXT_BUFFER_IN_80x25_VIDEO_MODE 160
#define COM1_BASE_PORT 0x3F8

extern void enable_paging(uint32_t* page_directory_physical_address);

// Note: Add `__attribute__((packed))` if this global variable is a struct.
__attribute__((aligned(4096)))
uint32_t page_directory[1024];
uint8_t* vga_text_buffer_current_address = (uint8_t*)VGA_TEXT_BUFFER_START_ADDRESS;

// --- Wrappers around the `outb` and `inb` Assembly instructions that allow the computer to perform I/O over ports ---
extern inline void write_byte_to_io_port(uint16_t io_port, uint8_t byte) {
  asm volatile ("outb %0, %1" : : "a"(byte), "Nd"(io_port));
}

extern inline uint8_t read_byte_from_io_port(uint16_t io_port) {
  uint8_t byte;
  asm volatile("inb %0, %1" : : "Nd"(io_port), "a"(byte));
  return byte;
}
// --- End of section ---

void init_com1_serial_port() {
  // Disable all interrupts for the COM1 serial port by writing the specified byte to the IER (Interrupt Enable Register) of the UART (Universal Asynchronous Receiver-Transmitter) chip.
  write_byte_to_io_port(COM1_BASE_PORT + 1, 0);
  // Enable DLAB (Divisor Latch Access Bit) so that the baud rate divisor can be set by specifying the low and high bytes of the divisor via the ports at COM1_BASE_PORT and COM1_BASE_PORT + 1 respectively.
  write_byte_to_io_port(COM1_BASE_PORT + 3, 0x80);
  // Set the divisor to 1 in order to set the baud rate to 115200 bps. Formula to derive divisor: Divisor = 115200 / Desired baud rate
  write_byte_to_io_port(COM1_BASE_PORT, 1); // Set the low byte of the divisor.
  write_byte_to_io_port(COM1_BASE_PORT + 1, 0); // Set the high byte of the divisor.
  // Disable DLAB and configure the UART communication settings:
  // - Word length: 8 bits
  // - Number of stop bits: 1
  // - Parity: None
  write_byte_to_io_port(COM1_BASE_PORT + 3, 3);
  // Enable the 16550 UART FIFOs, clear them, and set the number of bytes required to trigger an interrupt to 14.
  write_byte_to_io_port(COM1_BASE_PORT + 2, 0xc7);
  // Turn on the DTR and RTS signal lines and set the OUT2 bit (bit 3) to enable interrupts from the UART to the interrupt controller (PIC/IOAPIC).
  write_byte_to_io_port(COM1_BASE_PORT + 4, 0xb);
  // Re-enable all interrupts (the `Received Data Available` and `Transmitter Holding Register Empty` interrupts) for the COM1 serial port.
  write_byte_to_io_port(COM1_BASE_PORT + 1, 3);
}

void write_to_com1_serial_port(uint8_t* chars) {
  while (*chars != 0) {
    write_byte_to_io_port(COM1_BASE_PORT, *chars);
    chars += sizeof(uint8_t);
  }
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

extern void kernel_main() {
  init_com1_serial_port();
  write_to_com1_serial_port("[Kernel] Initialized COM 1 serial port.\n");
  // enable_paging(page_directory);
}