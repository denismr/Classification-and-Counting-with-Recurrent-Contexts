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
local SingleKS = require 'support.SingleKS'
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
    output = 'out/AedesQuinx_out.csv',
    y_list = {'AA', 'CQ'}, -- positive comes first
    contexts = {1, 2, 3, 4, 5, 6},
    sz = 300,
  },
  ['AedesSex'] = {
    train = 'procdata/AedesSex_val.csv',
    test = 'procdata/AedesSex_test.csv',
    output = 'out/AedesSex_out.csv',
    y_list = {'F', 'M'}, -- positive comes first
    contexts = {1, 2, 3, 4, 5, 6},
    sz = 300,
  },
  ['ArabicSex'] = {
    train = 'procdata/ArabicSex_val.csv',
    test = 'procdata/ArabicSex_test.csv',
    output = 'out/ArabicSex_out.csv',
    y_list = {'male', 'female'}, -- positive comes first
    contexts = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9},
    sz = 200,
  },
  ['CMC'] = {
    train = 'procdata/CMC_val.csv',
    test = 'procdata/CMC_test.csv',
    output = 'out/CMC_out.csv',
    y_list = {1, 2}, -- positive comes first
    contexts = {1, 2},
    sz = 100,
  },
  ['QG'] = {
    train = 'procdata/QG_val.csv',
    test = 'procdata/QG_test.csv',
    output = 'out/QG_out.csv',
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
    output = 'out/WineQuality_out.csv',
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

local train = CSV(experiment.train)
local test = CSV(experiment.test)

train = Shuffle(train)
test = Shuffle(test)

local settings = {
  data = train,
  y_map = exp.y_map,
  y_list = exp.y_list,
  contexts = exp.contexts,
  context_pkeys = exp.context_pkeys,
  context_ykeys = exp.context_ykeys,
  ctx_map = exp.ctx_map,
}
local mset = {__index = settings}

local settings_L2 = setmetatable({
  L2 = true,
}, mset)

local settings_acc = setmetatable({
  adjusted_cc = true,
}, mset)

local quantifiers = {
  {
    label = 'cc',
    predictor = CC(settings),
  },
  {
    label = 'acc',
    predictor = CC(settings_acc),
  },
}

local systems = {
  {
    label = 'Baseline',
    predictor = Baseline(settings),
  },
  {
    label = 'Baseline2',
    predictor = RndSingle(settings),
  },
  {
    label = 'Topline',
    predictor = Topline(settings),
  },
  {
    label = 'Topline2',
    predictor = Topline2(settings),
  },
  {
    label = 'Single',
    predictor = Single(settings),
  },
  {
    label = 'Crossed',
    predictor = Crossed(settings),
  },
  {
    label = 'SingleKS',
    predictor = SingleKS(settings),
  },
}

for i, s in ipairs(systems) do
  s.label_ctx = s.label .. '_ctx' -- context
  s.label_p = s.label .. '_p' -- positive class proportion
  s.label_acc = s.label .. '_acc' -- accuracy
  s.label_cacc = s.label .. '_cacc' -- calibrated accuracy
  for j, q in ipairs(quantifiers) do
    s['label_q_' .. j] = s.label .. '_qnt_' .. q.label
  end
end

local stest = SplitData(test)

local sample = {}
local dhists = {}
local hists = {}
local entries = {}

for i = -1, #exp.contexts do dhists[i] = Histogram() end

for ip = 0, flags.maxp do
  local p = ip / flags.maxp

  local n_pos = math.floor(exp.sz * p)
  local n_neg = exp.sz - n_pos

  for it = 0, flags.it * #exp.contexts - 1 do
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

    local entry = {
      part = ip,
      outof = flags.maxp,
      n_pos = n_pos,
      n_neg = n_neg,
      actual_p = string.format('%.3f', p),
      actual_ctx = ctx_i,
    }

    for i, v in ipairs(systems) do
      local predicted_ctx, predicted_p = v.predictor(hists, ctx_i, sample)
      local predicted_acc = AccuracyForContext(predicted_ctx, sample)
      local calibrated_acc = CalibratedAccuracyForContext(predicted_ctx, predicted_p, exp.y_list[1], sample)
      entry[v.label_ctx] = predicted_ctx
      entry[v.label_p] = string.format('%.3f', predicted_p)
      entry[v.label_acc] = string.format('%.3f', predicted_acc)
      entry[v.label_cacc] = string.format('%.3f', calibrated_acc)
      for j, q in ipairs(quantifiers) do
        entry[v['label_q_' .. j]] = q.predictor:Predict(sample, predicted_ctx)
      end
    end

    entries[#entries + 1] = entry
  end
end

local out_header = {'part', 'outof', 'n_pos', 'n_neg', 'actual_p', 'actual_ctx'}
for i, v in ipairs(systems) do
  out_header[#out_header + 1] = v.label_p
  out_header[#out_header + 1] = v.label_ctx
  out_header[#out_header + 1] = v.label_acc
  out_header[#out_header + 1] = v.label_cacc
  for j, q in ipairs(quantifiers) do
    out_header[#out_header + 1] = v['label_q_' .. j]
  end
end

CSV(entries, out_header, exp.output)
