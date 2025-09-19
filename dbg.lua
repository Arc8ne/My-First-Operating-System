#!/usr/bin/env lua
local utils = require("lua/utils")

local run = utils.run

local lfs = require("lfs")

function get_host_os_id()
  local uname_fd = io.popen("uname", "r")

  local uname_output = uname_fd:read("*a")

  uname_output = uname_output:gsub("\n", "")

  uname_fd:close()

  if type(uname_output) == "string" then return uname_output end

  local path_sep = package.config:sub(1, 1)

  if path_sep == "\\" then return "Windows" end

  return "Unknown"
end

local host_os_id = get_host_os_id()

bochs_cfg_file_path = lfs.currentdir() .. "/bochs-cfgs/" .. host_os_id:sub(1, 1):lower() .. host_os_id:sub(2)

bochs_cfg_file, error_msg, error_code = io.open(bochs_cfg_file_path, "r")
if bochs_cfg_file == nil then
  error("Unable to find the corresponding Bochs configuration file for the current host OS.\nError message: " .. error_msg .. "\nError code: " .. error_code)
  return 1
end
bochs_cfg_file:close()

local bochs_cmd = "bochs -q -f " .. bochs_cfg_file_path

-- Insert the `-debugger` flag if running on Windows.
if host_os_id == "Windows" then bochs_cmd = bochs_cmd:sub(1,9) .. "-debugger" .. bochs_cmd:sub(9) end

run(bochs_cmd)
