local leaf_index = {}
local leaf_meta = {__index = leaf_index}

local function bucket(proba)
  return math.max(1, math.min(11, math.ceil(11 * proba)))
end

local function Normalize(array, norm)
  local sum = 0
  for i, v in ipairs(array) do
    sum = sum + v
  end
  for i, v in ipairs(array) do
    norm[i] = v / sum
  end
  return norm
end

function leaf_index:Histogram()
  return Normalize(self.counter, self.buffer)
end

function leaf_index:Reset()
  local c = self.counter
  for i = 1, #c do
    c[i] = 0
  end
  return self
end

function leaf_index:Increment(proba)
  local b = bucket(proba)
  self.counter[b] = self.counter[b] + 1
end

function leaf_index:Decrement(proba)
  local b = bucket(proba)
  self.counter[b] = self.counter[b] - 1
end

local function NewLeaf()
  return setmetatable({
    counter = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    buffer  = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
  }, leaf_meta)
end

return NewLeaf
