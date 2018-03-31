local HDy = require 'support.HDy'
local L2y = require 'support.L2y'

local index = {}
local meta = {__index = index}

function index:Predict(hists, ctx)
  return ctx, self.hdys[ctx]:P(hists[ctx])
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