#!/usr/bin/env lua
local utils = require("lua/utils")

local host_os_id = utils.get_host_os_id()

local run = function(cmd)
  if host_os_id == "Windows" then return utils.run("wsl " .. cmd) end

  return utils.run(cmd)
end

-- Build the bootloader.
run("nasm -f bin -o bin/bootloader.bin src/bootloader/main.asm")

-- Build the kernel using `clang` as it supports cross-compilation out of the box.
run("clang -ffreestanding -fno-builtin -nostdlib -nostdinc -T kernel.ld -o bin/kernel.bin src/kernel/*.c")

-- Create a floppy disk image.
run("cat bin/bootloader.bin bin/kernel.bin > bin/floppy.img")

-- We add this since we are simulating a 1_44 floppy disk (i.e. floppy disk with a total size of 1.44 MB).
run("truncate -s 1440k bin/floppy.img")
