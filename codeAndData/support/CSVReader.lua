local Writer = require 'support.CSVWriter'

local missing_values = {
  na = true,
  nan = true,
  null = true,
  ['?'] = true,
  ['nil'] = true,
}

local function SelfSufficientTables(filename, force_header)
  local header = {}
  local csv = {}
  local f = io.open(filename, 'r')
  if not f then return end
  do
    local line = f:read()
    for field in (line..','):gmatch '%s*"?(.-)"?%s*[;,]' do
      header[#header + 1] = field
    end
  end
  if force_header then
    header = force_header
  end
  for line in f:lines() do
    if line then
      local has_content = line:match '[^\t\r ]'
      if has_content == '' then line = nil end
    end
    if line then
      local entry = {}
      local i = 1

      for value in line:gmatch '[^;,\r\n]+' do
        local set_value = tonumber(value)
        local lower_value = value:lower()
        if missing_values[lower_value] then
          set_value = false
        elseif not set_value then
          set_value = value:match '^%s*"*(.-)"*%s*$'
        end

        entry[header[i]] = set_value
        i = i + 1
      end
      csv[#csv + 1] = entry
    end
  end
  f:close()
  return csv, header
end

return setmetatable({
  SelfSufficientTables = SelfSufficientTables,
  ["in"] = SelfSufficientTables,
  In = SelfSufficientTables,
  Read = SelfSufficientTables,
  Reader = SelfSufficientTables,
  R = SelfSufficientTables,
  r = SelfSufficientTables,
  from = SelfSufficientTables,
  From = SelfSufficientTables,
  Writer = Writer,
  Write = Writer,
  W = Writer,
  w = Writer,
  To = Writer,
  to = Writer,
  Out = Writer,
  out = Writer,
}, {__call = function(self, ...)
  local p1 = select(1, ...)
  if type(p1) == 'table' then
    local p2, p3, p4 = select(2, ...)
    return Writer(p3, p1, p2, p4)
  end
  return SelfSufficientTables(...)
end})