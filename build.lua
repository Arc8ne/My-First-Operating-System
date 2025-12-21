#!/usr/bin/env lua
local utils = require("lua/utils")
local host_os_id = utils.get_host_os_id()
local run = function(cmd)
  if host_os_id == "Windows" then return utils.run("wsl " .. cmd) end
  return utils.run(cmd)
end
local exit_if_fail = function(cmd)
  local exit_code = run(cmd)
  if exit_code ~= 0 then os.exit(exit_code) end
end
local get_num_bytes_in_file = function(file_path)
  local file, _ = io.open(file_path, "rb")
  local start_pos = file:seek()
  local num_bytes_in_file = file:seek("end")
  file:seek("set", start_pos)
  file:close()
  return num_bytes_in_file
end
local compile_kernel = function(kernel_starting_memory_address)
  local kernel_compile_cmd = "clang -m32 -ffreestanding -fno-builtin -nostdlib -fno-PIC -o bin/kernel.bin src/kernel/*.c"
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
]], kernel_starting_memory_address)
  -- TODO: Add support for Windows.
  exit_if_fail(
    string.format(
      "bash -c '%s -T <(echo \"%s\")'",
      kernel_compile_cmd,
      kernel_linker_script
    )
  )
end
-- Compile the kernel with a placeholder starting memory address specified in the generated linker script so that the bootloader's 2nd stage can still have access to the actual size of the kernel binary.
-- Note: `clang` is used as the compiler as it supports cross-compilation out of the box.
compile_kernel(0x800a)
-- Build the 2nd stage (i.e. post-MBR) of the bootloader.
local num_bytes_per_sector = 512
local kernel_binary_size_in_bytes = get_num_bytes_in_file("bin/kernel.bin")
local kernel_binary_size_in_sectors = math.ceil(
  kernel_binary_size_in_bytes / num_bytes_per_sector
)
exit_if_fail("nasm -f bin -o bin/bootloader/2nd-stage.bin -d KERNEL_SIZE_IN_SECTORS=" .. kernel_binary_size_in_sectors .. " src/bootloader/2nd-stage/main.asm")
local bootloader_stage_2_binary_size_in_bytes = get_num_bytes_in_file("bin/bootloader/2nd-stage.bin")
local bootloader_stage_2_binary_size_in_sectors = math.ceil(
  bootloader_stage_2_binary_size_in_bytes / num_bytes_per_sector
)
exit_if_fail("truncate -s " .. bootloader_stage_2_binary_size_in_sectors * num_bytes_per_sector .. " bin/bootloader/2nd-stage.bin")
-- Re-compile the kernel with its actual starting memory address specified in the generated linker script.
local bootloader_stage_2_start_address = 0x7e00
local kernel_unaligned_start_address = 0x7e00 + bootloader_stage_2_binary_size_in_bytes
local kernel_aligned_start_address = kernel_unaligned_start_address + (16 - (kernel_unaligned_start_address % 16))
compile_kernel(kernel_aligned_start_address)
-- Build the 1st stage (i.e. MBR) of the bootloader.
exit_if_fail("nasm -f bin -o bin/bootloader/1st-stage.bin -d BOOTLOADER_STAGE_2_SIZE_IN_SECTORS=" .. bootloader_stage_2_binary_size_in_sectors .. " src/bootloader/1st-stage/main.asm")
-- Create a floppy disk image.
exit_if_fail("cat bin/bootloader/1st-stage.bin bin/bootloader/2nd-stage.bin bin/kernel.bin > bin/floppy.img")
-- We add this since we are simulating a 1_44 floppy disk (i.e. floppy disk with a total size of 1.44 MB).
exit_if_fail("truncate -s 1440k bin/floppy.img")
utils.print_green_text("Build succeeded.")
