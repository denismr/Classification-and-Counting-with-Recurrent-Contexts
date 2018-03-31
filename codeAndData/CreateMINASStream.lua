require 'vendor.fun.fun'()
require 'support.BlockGlobal'
local Flags = require 'support.flags'
local CSV = require 'support.CSV'
local Shuffle = require 'support.Shuffle'
local Split = require 'support.Split'

local Histogram = require 'support.TPHistogram'

local Baseline = require 'support.Baseline'
local RndSingle = require 'support.RndSingle'
local Topline = require 'support.Topline'
local Topline2 = require 'support.Topline2'
local Single = require 'support.Single'
local Crossed = require 'support.Crossed'
local CC = require 'support.CC'

local flags = Flags {
  ['exp'] = 'AedesQuinx',
  ['maxp'] = 100,
  ['it'] = 10,
}:processArgs(arg)

local experiments = {
  ['AedesQuinx'] = {
    train = 'procdata/AedesQuinx_val.csv',
    test = 'procdata/AedesQuinx_test.csv',
    original_data = 'data/AedesQuinx.csv',
    output_train = 'streams/AedesQuinx_train.csv',
    output_test = 'streams/AedesQuinx_test.csv',
    output_header = {"wbf","eh_1","eh_2","eh_3","eh_4","eh_5","eh_6","eh_7","eh_8","eh_9","eh_10","eh_11","eh_12","eh_13","eh_14","eh_15","eh_16","eh_17","eh_18","eh_19","eh_20","eh_21","eh_22","eh_23","eh_24","eh_25"},
    output_class = 'species',
    y_list = {'AA', 'CQ'}, -- positive comes first
    contexts = {1, 2, 3, 4, 5, 6},
    sz = 300,
  },
  ['AedesSex'] = {
    train = 'procdata/AedesSex_val.csv',
    test = 'procdata/AedesSex_test.csv',
    original_data = 'data/AedesSex.csv',
    output_train = 'streams/AedesSex_train.csv',
    output_test = 'streams/AedesSex_test.csv',
    output_header = {"wbf","eh_1","eh_2","eh_3","eh_4","eh_5","eh_6","eh_7","eh_8","eh_9","eh_10","eh_11","eh_12","eh_13","eh_14","eh_15","eh_16","eh_17","eh_18","eh_19","eh_20","eh_21","eh_22","eh_23","eh_24","eh_25"},
    output_class = 'sex',
    y_list = {'F', 'M'}, -- positive comes first
    contexts = {1, 2, 3, 4, 5, 6},
    sz = 300,
  },
  ['ArabicSex'] = {
    train = 'procdata/ArabicSex_val.csv',
    test = 'procdata/ArabicSex_test.csv',
    original_data = 'data/ArabicDigit.csv',
    output_train = 'streams/ArabicSex_train.csv',
    output_test = 'streams/ArabicSex_test.csv',
    output_header = function(x) return x ~= 'sex' and x ~= 'digit' end,
    output_class = 'sex',
    y_list = {'male', 'female'}, -- positive comes first
    contexts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9},
    sz = 180,
  },
  ['CMC'] = {
    train = 'procdata/CMC_val.csv',
    test = 'procdata/CMC_test.csv',
    original_data = 'data/CMC.csv',
    output_train = 'streams/CMC_train.csv',
    output_test = 'streams/CMC_test.csv',
    output_header = function(x) return x ~= 'contraceptive' and x ~= 'wifes_age' end,
    output_class = 'contraceptive',
    y_list = {1, 2}, -- positive comes first
    contexts = {1, 2},
    sz = 100,
  },
  ['QG'] = {
    train = 'procdata/QG_val.csv',
    test = 'procdata/QG_test.csv',
    original_data = 'data/qg.csv',
    output_train = 'streams/QG_train.csv',
    output_test = 'streams/QG_test.csv',
    output_header = function(x) return x ~= 'author' and x ~= 'letter' end,
    output_class = 'letter',
    y_list = {'q', 'g'}, -- positive comes first
    contexts = {
      'Andre', 'Antonio', 'Denis', 'Diego', 'Felipe',
      'Gustavo', 'Minatel', 'Rita', 'Roberta', 'Sanches',
    },
    sz = 80,
  },
  ['WineQuality'] = {
    train = 'procdata/WineQuality_val.csv',
    test = 'procdata/WineQuality_test.csv',
    original_data = 'data/winequality.csv',
    output_train = 'streams/WineQuality_train.csv',
    output_test = 'streams/WineQuality_test.csv',
    output_header = function(x) return x ~= 'quality' and x ~= 'type' end,
    output_class = 'quality',
    y_list = {'higher', 'lower'}, -- positive comes first
    contexts = {1, 2},
    sz = 300,
  },
}

if not experiments[flags.exp] then
  print 'Invalid experiment'
  return 0
end

local experiment = experiments[flags.exp]
local exp = experiment
experiment.context_pkeys = {[-1] = 'topline_p', [0] = 'baseline_p'}
experiment.context_ykeys = {[-1] = 'topline_y', [0] = 'baseline_y'}
experiment.y_map = tomap(zip(exp.y_list, range(#exp.y_list)))
experiment.ctx_map = tomap(zip(exp.contexts, range(#exp.contexts)))
for i, v in ipairs(experiment.contexts) do
  exp.context_pkeys[i] = v .. '_p'
  exp.context_ykeys[i] = v .. '_y'
end

local function SplitData(data)
  local function F(ctx, y)
    return function(x)
      return x.actual_context == ctx and x.actual_y == y
    end
  end

  local s = {}
  for ctx_i, ctx in ipairs(exp.contexts) do
    s[ctx_i] = {
      totable(filter(F(ctx, exp.y_list[1]), data)),
      totable(filter(F(ctx, exp.y_list[2]), data)),
    }
  end
  return s
end

local function AccuracyForContext(ctx_i, sample)
  local yk = exp.context_ykeys[ctx_i]
  local corrects = 0

  return sum(map(function(x)
    return x[yk] == x.actual_y and 1 or 0
  end, sample)) / #sample
end

local function CalibratedAccuracyForContext(ctx_i, p, pcl, sample)
  local pos = math.floor(p * #sample + 0.5)
  local neg = #sample - pos

  local pk = exp.context_pkeys[ctx_i]
  table.sort(sample, function(a, b)
    return a[pk] < b[pk]
  end)

  local corrects = 0

  return (sum(map(function(x)
    return x.actual_y ~= pcl and 1 or 0
  end, take_n(neg, sample)))
    + sum(map(function(x)
      return x.actual_y == pcl and 1 or 0
    end, drop_n(neg, sample)))) / #sample
end

local function ClearBuffer(buf)
  for i = 1, #buf do
    buf[i] = nil
  end
end

local function QuickSampleN(n, data, sample)
  local L = #data

  for i = 1, n do
    local j = math.random(math.max(0, L))
    sample[#sample + 1] = data[j]
    data[j], data[L] = data[L], data[j]
    L = L - 1
  end
end

local original_data, original_header = CSV(experiment.original_data)

if type(exp.output_header) ~= 'table' then
  exp.output_header = totable(filter(exp.output_header, original_header))
end
table.insert(exp.output_header, exp.output_class)

local train = CSV(experiment.train)
local test = CSV(experiment.test)

train = Shuffle(train)
test = Shuffle(test)


local stream_train = {}
local stream_test = {}
local samples = {}

local settings = {
  data = train,
  y_map = exp.y_map,
  y_list = exp.y_list,
  contexts = exp.contexts,
  context_pkeys = exp.context_pkeys,
  context_ykeys = exp.context_ykeys,
  ctx_map = exp.ctx_map,
}
local predictor = Crossed(settings)

local stest = SplitData(test)

for it = 0, flags.it * #exp.contexts - 1 do
  local inner_samples = {}

  local ctx_i = (it % #exp.contexts) + 1

  for ip = 0, flags.maxp do
    local p = ip / flags.maxp

    local n_pos = math.floor(exp.sz * p)
    local n_neg = exp.sz - n_pos
    local sample = {}
    assert(n_pos <= #stest[ctx_i][1])
    assert(n_neg <= #stest[ctx_i][2])
    QuickSampleN(n_pos, stest[ctx_i][1], sample)
    QuickSampleN(n_neg, stest[ctx_i][2], sample)
    Shuffle(sample)

    table.insert(inner_samples, sample)
  end

  Shuffle(inner_samples)
  for i, v in ipairs(inner_samples) do
    table.insert(samples, v)
  end
end

local xo_stream = {}
for i, sample in ipairs(samples) do
  for j, v in ipairs(sample) do
    table.insert(xo_stream, v) 
  end
end

local sliding, xo_stream = Split(xo_stream, exp.sz)
local xo_corrects = 0
local nxt = 1

local dhists = {}
local hists = {}

for i = -1, #exp.contexts do dhists[i] = Histogram() end

local function SetDHists(sample)
  for i = -1, #dhists do dhists[i]:Reset() end
  for ctx_i = -1, #exp.contexts do
    local pk = exp.context_pkeys[ctx_i]
    local function f(x) dhists[ctx_i]:Increment(x[pk]) end
    each(f, sample)
    hists[ctx_i] = dhists[ctx_i]:Histogram()
  end
end

SetDHists(sliding)

local function GetContext(old, new)
  for ctx_i = -1, #exp.contexts do
    local pk = exp.context_pkeys[ctx_i]
    dhists[ctx_i]:Decrement(old[pk])
    dhists[ctx_i]:Increment(new[pk])
    hists[ctx_i] = dhists[ctx_i]:Histogram()
  end
  return predictor(hists)
end

for i, v in ipairs(xo_stream) do
  local old = sliding[nxt]
  sliding[nxt] = v
  nxt = nxt + 1
  if nxt > #sliding then
    nxt = 1
  end

  local ctx = GetContext(old, v)
  local yk = exp.context_ykeys[ctx]

  xo_corrects = xo_corrects + (v[yk] == v.actual_y and 1 or 0)
end

print(xo_corrects / #xo_stream)

-- for i, v in ipairs(train) do
--   table.insert(stream_train, original_data[v.original_index + 1]) 
-- end

-- for i, sample in ipairs(samples) do
--   for j, v in ipairs(sample) do
--     table.insert(stream_test, original_data[v.original_index + 1]) 
--   end
-- end

-- CSV(stream_train, exp.output_header, exp.output_train)
-- CSV(stream_test, exp.output_header, exp.output_test)

for i, v in ipairs(train) do
  table.insert(stream_train, {index = v.original_index}) 
end

for i, sample in ipairs(samples) do
  for j, v in ipairs(sample) do
    table.insert(stream_test, {index = v.original_index}) 
  end
end

CSV(stream_train, {'index'}, exp.output_train)
CSV(stream_test, {'index'}, exp.output_test)

