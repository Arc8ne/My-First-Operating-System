local exports = {}

exports.run = function(cmd)
  print("> " .. cmd)

  return os.execute(cmd)
end

return exports
