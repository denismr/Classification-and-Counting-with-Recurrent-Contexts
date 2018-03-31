local HDy = require 'support.HDy'
local L2y = require 'support.L2y'

local index = {}
local meta = {__index = index}

function index:Predict(hists)
  local min_dist = math.huge
  local f_ctx = 1
  local f_p = 0

  for ctx_i, hdy in ipairs(self.hdys) do
    local p = hdy:P(hists[ctx_i])
    local dist = hdy:D(hists[ctx_i], p)
    if dist < min_dist then
      f_ctx = ctx_i
      f_p = p
      min_dist = dist
    end
  end

  return f_ctx, f_p
end

meta.__call = index.Predict

return function(settings)
  local hdys = {}
  for ctx_i = 1, #settings.contexts do
    hdys[ctx_i] = settings.L2 and L2y() or HDy()
  end
  local y_map = settings.y_map

  for i, v in ipairs(settings.data) do
    local ctx_i = settings.ctx_map[v.actual_context]
    local hdy = hdys[ctx_i]
    hdy:IncrementTrain(y_map[v.actual_y], v[settings.context_pkeys[ctx_i]])
  end
  return setmetatable({
    hdys = hdys,
  }, meta)
end