setmetatable(_G, {
  __index = function(_, key)
    error(string.format('"%s" is an inexistent global value.', key))
  end,
  __newindex = function(_, key)
    error(string.format('Setting global variable "%s" is forbidden!', key))
  end
})
