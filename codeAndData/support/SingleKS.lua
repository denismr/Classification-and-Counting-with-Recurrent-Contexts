local KS = (require 'support.KolmogorovSmirnov').Stat
local Topline = require 'support.Topline'

local index = {}
local meta = {__index = index}

function index:Predict(hists, IGNORE, sample)
  local min_ks = math.huge
  local f_ctx = 1

  if #sample < #self.buffer then
    self.buffer = {}
  end
  
  local buffer = self.buffer
  local context_pkeys = self.context_pkeys

  for ctx_i, ksample in ipairs(self.ksamples) do
    for i, v in ipairs(sample) do
      buffer[i] = v[context_pkeys[ctx_i]]
    end

    local ks = KS(ksample, buffer)

    if ks < min_ks then
      min_ks = ks
      f_ctx = ctx_i
    end
  end

  local ignore, f_p = self.topline(hists, f_ctx)

  return f_ctx, f_p
end

meta.__call = index.Predict

return function(settings)
  local ctxs = #settings.contexts

  local ksamples = {}
  for ctx_i = 1, ctxs do
    ksamples[ctx_i] = {}
  end

  for i, v in ipairs(settings.data) do
    local ctx_i = settings.ctx_map[v.actual_context]
    local ks = ksamples[ctx_i]
    table.insert(ks, v[settings.context_pkeys[ctx_i]])
  end
  
  return setmetatable({
    context_pkeys = settings.context_pkeys,
    buffer = {},
    ksamples = ksamples,
    topline = Topline(settings),
  }, meta)
end