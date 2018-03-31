local leaf_index = {}
local leaf_meta = {__index = leaf_index}

local function TernarySearch(left, right, f, eps)
  repeat
    if math.abs(left - right) < eps then return (left + right) / 2 end

    local leftThird = left + (right - left) / 3
    local rightThird = right - (right - left) / 3

    if f(leftThird) > f(rightThird) then
      left = leftThird
    else
      right = rightThird
    end
  until nil
end

local function SetZero(array)
  for i = 1, #array do
    array[i] = 0
  end
end

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

local function L2(pos_hist, neg_hist, pos, target_hist)
  local sum = 0
  for i = 1, #target_hist do
    sum = sum + ((pos_hist[i] * pos + neg_hist[i] * (1 - pos)) - (target_hist[i])) ^ 2
    -- sum = sum + (math.sqrt(pos_hist[i]) * pos + math.sqrt(neg_hist[i]) * (1 - pos) - math.sqrt(target_hist[i])) ^ 2
  end
  return math.sqrt(sum)
end

local function Alpha(pos_hist, neg_hist, target_hist)
  local den = 0
  local nom = 0
  for i = 1, #target_hist do
    nom = nom + (pos_hist[i] - neg_hist[i]) * (target_hist[i] - neg_hist[i])
    den = den + (pos_hist[i] - neg_hist[i]) ^ 2
  end
  return math.min(1, math.max(0, nom / den))
end

function leaf_index:P(target_hist)
  target_hist = target_hist or Normalize(self.test_counter, self.test_buffer)
  self.train_hist[1] = self.train_hist[1] or Normalize(self.train_counter[1], self.train_buffer[1])
  self.train_hist[2] = self.train_hist[2] or Normalize(self.train_counter[2], self.train_buffer[2])
  return Alpha(self.train_hist[1], self.train_hist[2], target_hist)
end

function leaf_index:L2(target_hist, pos)
  target_hist = target_hist or Normalize(self.test_counter, self.test_buffer)
  self.train_hist[1] = self.train_hist[1] or Normalize(self.train_counter[1], self.train_buffer[1])
  self.train_hist[2] = self.train_hist[2] or Normalize(self.train_counter[2], self.train_buffer[2])
  return L2(self.train_hist[1], self.train_hist[2], pos, target_hist)
end

leaf_index.Ratio = leaf_index.P
leaf_index.Proportion = leaf_index.P
leaf_index.Distance = leaf_index.L2
leaf_index.D = leaf_index.L2

function leaf_index:_reset()
  self:_resetTest()
  self:_resetTrain()
  return self
end

function leaf_index:_resetTrain()
  SetZero(self.train_counter[1])
  SetZero(self.train_counter[2])
  self.train_hist = {nil, nil}
  return self
end

function leaf_index:_resetTest()
  SetZero(self.test_counter)
  self.test_total = 0
  return self
end

function leaf_index:IncrementTrain(actual, proba)
  self.train_hist[actual] = nil
  local b = bucket(proba)
  self.train_counter[actual][b] = self.train_counter[actual][b] + 1
end

function leaf_index:DecrementTrain(actual, proba)
  self.train_hist[actual] = nil
  local b = bucket(proba)
  self.train_counter[actual][b] = self.train_counter[actual][b] - 1
end

function leaf_index:Increment(proba)
  local b = bucket(proba)
  self.test_counter[b] = self.test_counter[b] + 1
  self.test_total = self.test_total + 1
end

function leaf_index:Decrement(proba)
  local b = bucket(proba)
  self.test_counter[b] = self.test_counter[b] - 1
  self.test_total = self.test_total - 1
end

local function NewLeaf()
  return setmetatable({
    train_buffer = {{}, {}},
    test_buffer = {},
    train_counter = {
      {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
      {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
    },
    test_counter = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0},
  }, leaf_meta):_reset()
end

return NewLeaf
