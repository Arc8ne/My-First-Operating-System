#!/usr/bin/env lua
local utils = require("lua/utils")

utils.run_and_exit_if_fail("qemu-system-i386 -boot d -cdrom bin/os.iso -serial stdio")