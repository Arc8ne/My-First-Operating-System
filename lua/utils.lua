local exports = {}

exports.run = function(cmd)
  print("> " .. cmd)
  return os.execute(cmd)
end

local print_red_text = function(text)
  print("\27[31m" .. text .. "\27[0m")
end

exports.run_and_exit_if_fail = function(cmd)
  local success, exit_type, exit_code = exports.run(cmd)
  if not success then
    print_red_text("A command failed with code: " .. tostring(exit_code))
    os.exit(exit_code)
  end
end

exports.get_host_os_id = function()
  -- local uname_fd = io.popen("uname", "r")
  -- local uname_output = uname_fd:read("*a")
  -- uname_output = uname_output:gsub("\n", "")
  -- uname_fd:close()
  -- local path_separator = package.config:sub(1, 1)
  -- if uname_output == "" and path_separator == "\\" then return "Windows" end
  -- if type(uname_output) == "string" then return uname_output end
  -- return "Unknown"

  -- `package.config` is a string which contains the current host platform's directory separator as its 1st character, this can be used to determine the host operating system.
  local dir_separator = package.config:sub(1, 1)
  if dir_separator == "\\" then return "Windows" end
  if dir_separator == "/" then return "Linux" end
  return "Unknown"
end

exports.print_green_text = function(text)
  print("\27[32m" .. text .. "\27[0m")
end

return exports