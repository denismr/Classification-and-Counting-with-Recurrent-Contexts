-- True = data are different
-- False = data can be equal

local function IsSorted(v)
  for i = 2, #v do
    if v[i] < v[i - 1] then
      return false
    end
  end
  return true
end

local function PrepareData(values, should_copy)
  if not IsSorted(values) then
    if should_copy then
      values = {unpack(values)}
    end
    table.sort(values)
  end
  return values
end

local function Iterate(v1, v2)
  local i1 = 1
  local i2 = 1

  return function()
    if i1 <= #v1 or i2 <= #v2 then
      if i1 > #v1 then
        i2 = i2 + 1
        return v2[i2 - 1]
      elseif i2 > #v2 then
        i1 = i1 + 1
        return v1[i1 - 1]
      end

      if v1[i1] < v2[i2] then
        i1 = i1 + 1
        return v1[i1 - 1]
      else
        i2 = i2 + 1
        return v2[i2 - 1]
      end
    end
  end
end

local function CountLessOrEqualThan(values, searched_value)
  local a = 1
  local b = #values
  local idx = 0

  while a <= b do
    local mid = math.floor(a / 2 + b / 2)
    if values[mid] > searched_value then
      b = mid - 1
    else
      idx = mid
      a = mid + 1
    end
  end
  return idx
end

local function Ft(values, t)
  return CountLessOrEqualThan(values, t) / #values
end

local function GetSupremum(values_a, values_b, should_copy_a, should_copy_b)
  values_a = PrepareData(values_a, should_copy_a)
  values_b = PrepareData(values_b, should_copy_b)

  local supremum = 0
  for t in Iterate(values_a, values_b) do
    supremum = math.max(supremum, math.abs(Ft(values_a, t) - Ft(values_b, t)))
  end

  return supremum
end

local function ApplyWithCA(values_a, values_b, ca, should_copy_a, should_copy_b)
  local supremum = GetSupremum(values_a, values_b, should_copy_a, should_copy_b)
  local n = #values_a
  local m = #values_b
  -- ca = ca or 1.22 -- 0.10
  -- ca = ca or 1.36 -- 0.05
  -- ca = ca or 1.48 -- 0.025
  -- ca = ca or 1.63 -- 0.01
  -- ca = ca or 1.73 -- 0.005
  -- ca = ca or 1.95 -- 0.001
  ca = ca or 1.95
  return supremum > ca * math.sqrt((n + m) / (n * m))
end

return setmetatable({
  V          = GetSupremum,
  Statistic  = GetSupremum,
  Stat       = GetSupremum,
  KSStat     = GetSupremum,
  D          = GetSupremum,
  Apply      = ApplyWithCA,
}, {
  __call = function(self, values_a, values_b, should_copy_a, should_copy_b, ca) -- compatibility with old code
    return ApplyWithCA(values_a, values_b, ca, should_copy_a, should_copy_b)
  end
})
