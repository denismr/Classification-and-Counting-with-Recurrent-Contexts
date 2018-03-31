local HDy = require 'support.HDy'
local L2y = require 'support.L2y'

local index = {}
local meta = {__index = index}

function index:Predict(hists)
  return 0, self.hdy:P(hists[0])
end

meta.__call = index.Predict

return function(settings)
  local hdy = settings.L2 and L2y() or HDy()
  local y_map = settings.y_map
  for i, v in ipairs(settings.data) do
    hdy:IncrementTrain(y_map[v.actual_y], v.baseline_p)
  end
  return setmetatable({
    hdy = hdy,
  }, meta)
end