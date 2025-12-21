local exports = {}

exports.run = function(cmd)
  print("> " .. cmd)

  return os.execute(cmd)
end

exports.get_host_os_id = function()
  local uname_fd = io.popen("uname", "r")

  local uname_output = uname_fd:read("*a")

  uname_output = uname_output:gsub("\n", "")

  uname_fd:close()

  local path_separator = package.config:sub(1, 1)

  if uname_output == "" and path_separator == "\\" then return "Windows" end

  if type(uname_output) == "string" then return uname_output end

  return "Unknown"
end

exports.print_green_text = function(text)
  print("\27[32m" .. text .. "\27[0m")
end

return exports
