#!/usr/bin/env lua
local utils = require("lua/utils")
local host_os_id = utils.get_host_os_id()
local run = function(cmd)
  if host_os_id == "Windows" then return utils.run("wsl " .. cmd) end
  return utils.run(cmd)
end
local get_num_bytes_in_file = function(file_path)
  local file, _ = io.open(file_path, "rb")
  local start_pos = file:seek()
  local num_bytes_in_file = file:seek("end")
  file:seek("set", start_pos)
  file:close()
  return num_bytes_in_file
end
-- Build the kernel using `clang` as it supports cross-compilation out of the box.
run("clang -m32 -ffreestanding -fno-builtin -nostdlib -fno-PIC -T kernel.ld -o bin/kernel.bin src/kernel/*.c")
local num_bytes_per_sector = 512
local kernel_binary_size_in_bytes = get_num_bytes_in_file("bin/kernel.bin")
local kernel_binary_size_in_sectors = math.ceil(
  kernel_binary_size_in_bytes / num_bytes_per_sector
)
-- Build the bootloader.
run("nasm -f bin -o bin/bootloader.bin -d KERNEL_SIZE_IN_SECTORS=" .. kernel_binary_size_in_sectors .. " src/bootloader/main.asm")
-- Create a floppy disk image.
run("cat bin/bootloader.bin bin/kernel.bin > bin/floppy.img")
-- We add this since we are simulating a 1_44 floppy disk (i.e. floppy disk with a total size of 1.44 MB).
run("truncate -s 1440k bin/floppy.img")
