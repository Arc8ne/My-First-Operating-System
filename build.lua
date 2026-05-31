#!/usr/bin/env lua
-- This script can be used to build both the dedicated bootloader (in the state that it was left off at) for this OS and the kernel.
-- However, this script is currently in the process of being deprecated as this project shifts towards using CMake for its builds instead.
local utils = require("lua/utils")

local get_num_bytes_in_file = function(file_path)
  local file, _ = io.open(file_path, "rb")
  local start_pos = file:seek()
  local num_bytes_in_file = file:seek("end")
  file:seek("set", start_pos)
  file:close()
  return num_bytes_in_file
end

-- A cross-platform implementation of copying a file at a specified path to a specified destination path.
-- This eliminates the need to account for different copy commands on different platforms that might have different flags, options, and/or arguments.
-- This function returns an empty string on success and a non-empty string on failure.
local copy_file = function(file_path, dest_path)
  local original_file = io.open(file_path, "rb")
  if not original_file then return "Failed to open original file." end

  local original_file_data = original_file:read("*a")
  original_file:close()

  local dest_file = io.open(dest_path, "wb")
  if not dest_file then return "Failed to open destination file." end

  dest_file:write(original_file_data)
  dest_file:close()
  return ""
end

-- Note: The specified address will be the physical address at which the kernel is loaded into memory at.
local build_kernel_with_custom_base_address = function(kernel_base_address)
  local kernel_compile_cmd =
  "clang -m32 -ffreestanding -fno-builtin -nostdlib -fno-PIC -o bin/kernel.bin src/kernel/*.c"
  local kernel_linker_script = string.format([[
OUTPUT_FORMAT("binary")
SECTIONS
{
  . = 0x%x;
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
]], kernel_base_address)
  -- TODO: Add support for Windows.
  utils.run_and_exit_if_fail(
      string.format(
          "bash -c '%s -T <(echo \"%s\")'",
          kernel_compile_cmd,
          kernel_linker_script
      )
  )
end

local build_bootloader_and_kernel = function()
  -- Compile the kernel with a placeholder starting memory address specified in the generated linker script so that the bootloader's 2nd stage can still have access to the actual size of the kernel binary.
  -- Note: `clang` is used as the compiler as it supports cross-compilation out of the box.
  build_kernel_with_custom_base_address(0x800a)
  -- Build the 2nd stage (i.e. post-MBR) of the bootloader.
  local num_bytes_per_sector = 512
  local kernel_binary_size_in_bytes = get_num_bytes_in_file("bin/kernel.bin")
  local kernel_binary_size_in_sectors = math.ceil(
    kernel_binary_size_in_bytes / num_bytes_per_sector
  )
  utils.run_and_exit_if_fail("nasm -f bin -o bin/bootloader/2nd-stage.bin -d KERNEL_SIZE_IN_SECTORS=" .. kernel_binary_size_in_sectors .. " src/bootloader/2nd-stage.asm")
  local bootloader_stage_2_binary_size_in_bytes = get_num_bytes_in_file("bin/bootloader/2nd-stage.bin")
  local bootloader_stage_2_binary_size_in_sectors = math.ceil(
    bootloader_stage_2_binary_size_in_bytes / num_bytes_per_sector
  )
  utils.run_and_exit_if_fail("truncate -s " .. bootloader_stage_2_binary_size_in_sectors * num_bytes_per_sector .. " bin/bootloader/2nd-stage.bin")
  -- Re-compile the kernel with its actual starting memory address specified in the generated linker script.
  local bootloader_stage_2_start_address = 0x7e00
  local kernel_unaligned_start_address = 0x7e00 + bootloader_stage_2_binary_size_in_bytes
  local kernel_aligned_start_address = kernel_unaligned_start_address + (16 - (kernel_unaligned_start_address % 16))
  build_kernel_with_custom_base_address(kernel_aligned_start_address)
  -- Build the 1st stage (i.e. MBR) of the bootloader.
  utils.run_and_exit_if_fail("nasm -f bin -o bin/bootloader/1st-stage.bin -d BOOTLOADER_STAGE_2_SIZE_IN_SECTORS=" .. bootloader_stage_2_binary_size_in_sectors .. " src/bootloader/1st-stage.asm")
end

local create_floppy_disk_img = function()
  -- Create a floppy disk image.
  utils.run_and_exit_if_fail("cat bin/bootloader/1st-stage.bin bin/bootloader/2nd-stage.bin bin/kernel.bin > bin/floppy.img")
  -- We add this since we are simulating a 1_44 floppy disk (i.e. floppy disk with a total size of 1.44 MB).
  utils.run_and_exit_if_fail("truncate -s 1440k bin/floppy.img")
end

-- This is the function used to build a Multiboot / Multiboot 2 compliant kernel that can be loaded by a bootloader that is compliant with either one or both of those protocols (i.e. GRUB).
local build_kernel = function()
  utils.run_and_exit_if_fail("nasm -f elf32 src/kernel/boot.asm -o bin/kernel-boot.o")
  utils.run_and_exit_if_fail("clang --target=i386-elf -m32 -ffreestanding -fno-builtin -nostdlib -fno-PIC -c src/kernel/*.c -o bin/kernel.o")
  utils.run_and_exit_if_fail("ld -m elf_i386 -T kernel.ld -o bin/os-iso-root/boot/kernel.elf bin/kernel-boot.o bin/kernel.o")
  -- Converts the outputted kernel binary from an ELF32 binary to a raw binary.
  -- Note: This is not needed currently as it is intended for the kernel to be built as an ELF binary.
  -- utils.run_and_exit_if_fail("objcopy -O binary bin/kernel.elf bin/kernel.bin")
end

-- Note: Unlike the `grub-mkrescue` command included in standard Linux distributions, there is no standard tool provided by default on Windows for creating ISO images via the command line. As a result, this script will need to be run in a Linux environment until support for Windows is implemented for this function.
local create_bootable_iso = function()
  utils.run_and_exit_if_fail("grub-mkrescue -o bin/os.iso bin/os-iso-root")
end

build_kernel()
create_bootable_iso()
utils.print_green_text("Build succeeded.")