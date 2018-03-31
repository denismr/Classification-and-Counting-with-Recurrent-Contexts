return function(dataset, elements_in_first)
  local a, b = {}, {}
  for i = 1, elements_in_first do
    table.insert(a, dataset[i])
  end
  for i = elements_in_first + 1, #dataset do
    table.insert(b, dataset[i])
  end
  return a, b
end
