#!/usr/bin/env lua
local utils = require("lua/utils")

local run = utils.run

run("qemu-system-i386 -drive file=bin/floppy.img,format=raw,if=floppy")
