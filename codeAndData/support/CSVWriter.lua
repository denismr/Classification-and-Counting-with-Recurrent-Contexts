return function(filename, csv, header, missing)
  missing = missing or '?'
  local to_print = {}
  for i = 1, #header do to_print[i] = missing end

  local file = io.open(filename, 'w')
  file:write(table.concat(header, ','), '\n')
  for _, v in ipairs(csv) do
    for i, h in ipairs(header) do
      to_print[i] = v[h] or missing
    end
    file:write(table.concat(to_print, ','), '\n')
  end
  file:close()
end