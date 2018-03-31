local HDy = require 'support.HDy'
local L2y = require 'support.L2y'

local index = {}
local meta = {__index = index}

function index:Predict(hists)
  local min_dist = math.huge
  local f_ctx = 1
  local f_p = 0

  for ctx_i, hdys in ipairs(self.hdyss) do

    local dist = 0
    for ctx_j, hdy in ipairs(hdys) do
      local p = hdy:P(hists[ctx_j])
      dist = dist + hdy:D(hists[ctx_j], p)
    end

    if dist < min_dist then
      f_ctx = ctx_i
      f_p = hdys[ctx_i]:P(hists[ctx_i])
      min_dist = dist
    end
  end

  return f_ctx, f_p
end

meta.__call = index.Predict

return function(settings)
  local ctxs = #settings.contexts
  local hdyss = {}
  for ctx_i = 1, ctxs do
    hdyss[ctx_i] = {}
    for ctx_j = 1, ctxs do
      hdyss[ctx_i][ctx_j] = settings.L2 and L2y() or HDy()
    end
  end

  local y_map = settings.y_map

  for i, v in ipairs(settings.data) do
    local ctx_i = settings.ctx_map[v.actual_context]
    local hdys = hdyss[ctx_i]
    local actual_y = y_map[v.actual_y]
    for ctx_j = 1, ctxs do
      local hdy = hdys[ctx_j]
      hdy:IncrementTrain(actual_y, v[settings.context_pkeys[ctx_j]])
    end
  end
  
  return setmetatable({
    hdyss = hdyss,
    ctxs = ctxs,
  }, meta)
end