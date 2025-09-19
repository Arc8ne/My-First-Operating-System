#!/usr/bin/env lua
local utils = require("lua/utils")

local run = utils.run

-- Build the bootloader.
run("nasm -f bin -o bin/bootloader.bin src/bootloader/main.asm")

-- Build the kernel.
run("gcc -ffreestanding -fno-pie -m32 -o bin/kernel.bin src/kernel/*.c")

-- Create a floppy disk image.
run("dd if=bin/bootloader.bin of=bin/floppy.img")

-- We add this since we are simulating a 1_44 floppy disk (i.e. floppy disk with a total size of 1.44 MB).
run("truncate -s 1440k bin/floppy.img")
