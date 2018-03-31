local HDy = require 'support.HDy'
local L2y = require 'support.L2y'


local leaf_index = {}
local leaf_meta = {__index = leaf_index}

local function UnclampedACC(p, tpr, fpr)
  if fpr == tpr then
    return p
  else
    return (p - fpr) / (tpr - fpr)
  end
end

local function ACC(p, tpr, fpr)
  return math.min(1, math.max(0, UnclampedACC(p, tpr, fpr)))
end

function leaf_index:_reset()
  self:_resetTest()
  self:_resetTrain()
  return self
end

function leaf_index:_resetTrain()
  self.train_cm[1][1] = 0
  self.train_cm[1][2] = 0
  self.train_cm[2][1] = 0
  self.train_cm[2][2] = 0
  self.tpr = 0
  self.fpr = 0
  self:_updateP()
  return self
end

function leaf_index:_resetTest()
  self.test_predictions[1] = 0
  self.test_predictions[2] = 0
  self.test_total = 0
  self.p = 0
  return self
end

function leaf_index:_incrementCM(predicted, actual)
  local cm = self.train_cm
  cm[predicted][actual] = cm[predicted][actual] + 1
end

function leaf_index:_decrementCM(predicted, actual)
  local cm = self.train_cm
  cm[predicted][actual] = cm[predicted][actual] - 1
end

function leaf_index:_updateTrain()
  local cm = self.train_cm
  local FN = cm[2][1]
  local TP = cm[1][1]
  
  local FP = cm[1][2]
  local TN = cm[2][2]
  
  self.tpr = TP / (TP + FN)
  self.fpr = FP / (FP + TN)

  self:_updateP()
end

function leaf_index:_updateP()
  local count = self.test_predictions
  local p = count[1] / (count[1] + count[2])
  if self.adjusted then
    self.p = ACC(p, self.tpr, self.fpr)
  else
    self.p = p
  end
end

function leaf_index:IncrementTrain(predicted, actual)
  self:_incrementCM(predicted, actual)
  self:_updateTrain()
end

function leaf_index:DecrementTrain(predicted, actual)
  self:_decrementCM(predicted, actual)
  self:_updateTrain()
end

function leaf_index:Increment(predicted)
  self.test_predictions[predicted] = self.test_predictions[predicted] + 1
  self.test_total = self.test_total + 1
  self:_updateP()
end

function leaf_index:Decrement(predicted)
  self.test_predictions[predicted] = self.test_predictions[predicted] - 1
  self.test_total = self.test_total - 1
  self:_updateP()
end

function leaf_index:P()
  return self.p
end

local function NewLeaf(adjusted)
  local leaf = setmetatable({
    train_cm = {{0, 0}, {0, 0}},
    test_predictions = {0, 0},
    adjusted = adjusted or false,
  }, leaf_meta):_reset()
  return leaf
end

local index = {}
local meta = {__index = index}

function index:Predict(examples, ctx_i)
  local cc = self.ccs[ctx_i]
  local y_map = self.y_map
  local yk = self.ykeys[ctx_i]
  cc:_resetTest()
  for i, v in ipairs(examples) do
    cc:Increment(y_map[v[yk]])
  end
  return cc:P()
end

meta.__call = index.Predict

return function(settings)
  local ccs = {}
  for ctx_i = -1, #settings.contexts do
    ccs[ctx_i] = NewLeaf(settings.adjusted_cc)
  end
  local y_map = settings.y_map
  local ykeys = settings.context_ykeys
  local ctx_map = settings.ctx_map

  for i, v in ipairs(settings.data) do
    local ctx_i = ctx_map[v.actual_context]
    local cc = ccs[ctx_i]
    cc:IncrementTrain(y_map[v[ykeys[ctx_i]]], y_map[v.actual_y])
    ccs[0]:IncrementTrain(y_map[v.topline_y], y_map[v.actual_y])
    ccs[-1]:IncrementTrain(y_map[v.topline_y], y_map[v.actual_y])
  end
  return setmetatable({
    ccs = ccs,
    ykeys = ykeys,
    y_map = y_map,
  }, meta)
end