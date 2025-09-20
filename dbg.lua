#!/usr/bin/env lua
local utils = require("lua/utils")

local run = utils.run

local host_os_id = utils.get_host_os_id()

bochs_cfg_file_path = "bochs-cfgs/" .. host_os_id:sub(1, 1):lower() .. host_os_id:sub(2)

local bochs_cmd = "bochs -q -f " .. bochs_cfg_file_path

-- Insert the `-debugger` flag if running on Windows.
if host_os_id == "Windows" then bochs_cmd = bochs_cmd:sub(1,9) .. "-debugger" .. bochs_cmd:sub(9) end

run(bochs_cmd)
