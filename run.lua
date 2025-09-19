local utils = require("lua/utils")

local run = utils.run

run("qemu-system-i386", "-fda", "bin/floppy.img")
