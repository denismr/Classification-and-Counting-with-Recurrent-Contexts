return function(v)
  for i = #v, 2, -1 do
    local j = math.random(i)
    v[i], v[j] = v[j], v[i]
  end
  return v
end