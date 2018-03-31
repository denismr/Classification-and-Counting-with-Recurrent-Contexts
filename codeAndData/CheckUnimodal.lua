require 'vendor.fun.fun'()
require 'support.BlockGlobal'
local Flags = require 'support.flags'
local CSV = require 'support.CSV'
local Shuffle = require 'support.Shuffle'

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
  ['parts'] = 1000,
  ['eps'] = 1e-5,
}:processArgs(arg)

local experiments = {
  ['AedesQuinx'] = {
    train = 'procdata/AedesQuinx_val.csv',
    test = 'procdata/AedesQuinx_test.csv',
    y_list = {'AA', 'CQ'}, -- positive comes first
    contexts = {1, 2, 3, 4, 5, 6},
    sz = 300,
  },
  ['AedesSex'] = {
    train = 'procdata/AedesSex_val.csv',
    test = 'procdata/AedesSex_test.csv',
    y_list = {'F', 'M'}, -- positive comes first
    contexts = {1, 2, 3, 4, 5, 6},
    sz = 300,
  },
  ['ArabicSex'] = {
    train = 'procdata/ArabicSex_val.csv',
    test = 'procdata/ArabicSex_test.csv',
    y_list = {'male', 'female'}, -- positive comes first
    contexts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9},
    sz = 200,
  },
  ['QG'] = {
    train = 'procdata/QG_val.csv',
    test = 'procdata/QG_test.csv',
    y_list = {'q', 'g'}, -- positive comes first
    contexts = {
      'Andre', 'Antonio', 'Denis', 'Diego', 'Felipe',
      'Gustavo', 'Minatel', 'Rita', 'Roberta', 'Sanches',
    },
    sz = 80,
  },
  ['CMC'] = {
    train = 'procdata/CMC_val.csv',
    test = 'procdata/CMC_test.csv',
    y_list = {1, 2}, -- positive comes first
    contexts = {1, 2},
    sz = 100,
  },
  ['WineQuality'] = {
    train = 'procdata/WineQuality_val.csv',
    test = 'procdata/WineQuality_test.csv',
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

local train = CSV(experiment.train)
local test = CSV(experiment.test)

train = Shuffle(train)
test = Shuffle(test)

local stest = SplitData(test)

local sample = {}
local dhists = {}
local hists = {}
local entries = {}

for i = -1, #exp.contexts do dhists[i] = Histogram() end

local train_hists = {}
do
  local train_dhists = {}
  for i = -1, #exp.contexts do
    train_dhists[i] = {Histogram(), Histogram()}
  end
  for i, v in ipairs(train) do
    local ctx_i = exp.ctx_map[v.actual_context]
    local y = exp.y_map[v.actual_y]
    local dh = train_dhists[ctx_i][y]
    dh:Increment(v[exp.context_pkeys[ctx_i]])
    dh = train_dhists[-1][y]
    dh:Increment(v.topline_p)
    dh = train_dhists[0][y]
    dh:Increment(v.baseline_p)
  end
  for i = -1, #exp.contexts do
    train_hists[i] = {
      train_dhists[i][1]:Histogram(),
      train_dhists[i][2]:Histogram(),
    }
  end
end

local function HD(pos_hist, neg_hist, pos, target_hist)
  local sum = 0
  for i = 1, #target_hist do
    sum = sum + (math.sqrt(pos_hist[i] * pos + neg_hist[i] * (1 - pos)) - math.sqrt(target_hist[i])) ^ 2
  end
  return math.sqrt(sum)
end

local function TernarySearch(left, right, f, eps)
  local depth = 0
  repeat
    depth = depth + 1
    if math.abs(left - right) < eps then return (left + right) / 2, depth end

    local leftThird = left + (right - left) / 3
    local rightThird = right - (right - left) / 3

    if f(leftThird) > f(rightThird) then
      left = leftThird
    else
      right = rightThird
    end
  until nil
end

local function CheckUnimodal(pos_hist, neg_hist, target_hist, parts)
  local previous = math.huge
  local i = 0

  local function f(x)
    return HD(pos_hist, neg_hist, x, target_hist)
  end
  local ts, tsd = TernarySearch(0, 1, f, flags.eps)

  local min_hd = math.huge
  local min_p = 0
  local err = 0
  
  for j = 0, parts do
    local p = j / parts
    local hd = f(p)
    if hd < min_hd then
      min_hd = hd
      min_p = p
      err = math.abs(p - ts)
    end
  end
  
  local disc_bt_ts = min_hd < f(ts) and 1 or 0

  while i <= parts do
    local p = i / parts
    local hd = f(p)
    if hd > previous then
      previous = hd
      i = i + 1
      break
    end
    previous = hd
    i = i + 1
  end
  while i <= parts do
    local p = i / parts
    local hd = f(p)
    if hd < previous then
      return false, err, tsd, disc_bt_ts
    end
    previous = hd
    i = i + 1
  end
  return true, err, tsd, disc_bt_ts
end

local unimodals = 0
local nonunimodals = 0
local tot_err = 0
local tot_depth = 0
local tot_dbtts = 0
local vec_err = {}

for ip = 0, flags.maxp do
  local p = ip / flags.maxp

  local n_pos = math.floor(exp.sz * p)
  local n_neg = exp.sz - n_pos

  for it = 0, flags.it * #exp.contexts - 1 do
    -- local ctx_i = math.random(#exp.contexts)
    local ctx_i = (it % #exp.contexts) + 1
    ClearBuffer(sample)
    assert(n_pos <= #stest[ctx_i][1])
    assert(n_neg <= #stest[ctx_i][2])
    QuickSampleN(n_pos, stest[ctx_i][1], sample)
    QuickSampleN(n_neg, stest[ctx_i][2], sample)

    for i = -1, #dhists do dhists[i]:Reset() end

    for ctx_i = -1, #exp.contexts do
      local pk = exp.context_pkeys[ctx_i]
      local function f(x) dhists[ctx_i]:Increment(x[pk]) end
      each(f, sample)
      hists[ctx_i] = dhists[ctx_i]:Histogram()
    end

    for ctx_i = -1, #exp.contexts do
      for ctx_j = -1, #exp.contexts do
        local check, err, depth, dbtts = CheckUnimodal(train_hists[ctx_j][1], train_hists[ctx_j][2], hists[ctx_i], flags.parts)
        table.insert(vec_err, err)
        tot_err = tot_err + err
        tot_depth = tot_depth + depth
        tot_dbtts = tot_dbtts + dbtts
        if check then
          unimodals = unimodals + 1
        else
          nonunimodals = nonunimodals + 1
        end
      end
    end

  end
end

local sum = 0
for i, v in ipairs(vec_err) do
  sum = sum + v
end
local mu = sum / #vec_err
sum = 0
for i, v in ipairs(vec_err) do
  sum = sum + (v - mu)^2
end
local sdev = math.sqrt(sum / (#vec_err - 1))


print('     T     ', unimodals)
print('     F     ', nonunimodals)
print('   T + F   ', unimodals + nonunimodals)
print('T / (T + F)', unimodals / (unimodals + nonunimodals))
print('F / (T + F)', nonunimodals / (unimodals + nonunimodals))
print('    MAE    ', tot_err / (unimodals + nonunimodals))
print('   DEPTH   ', tot_depth / (unimodals + nonunimodals))
print('   DBTTS   ', tot_dbtts / (unimodals + nonunimodals))
print('    M U    ', mu)
print('    S D   ', sdev)