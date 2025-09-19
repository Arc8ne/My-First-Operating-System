local lc = require("luachild")

local exports = {}

exports.run = function(...)
  local process_spawn_args = {...}

  process_spawn_args.stdin = io.stdin

  process_spawn_args.stdout = io.stdout

  process_spawn_args.stderr = io.stderr

  print("[Command] {" .. table.concat({...}, ", ") .. "}")

  local process = lc.spawn(process_spawn_args)

  if process == nil then
    print("[Command status] Failed to run.")

    return
  end

  process:wait()
end

return exports
