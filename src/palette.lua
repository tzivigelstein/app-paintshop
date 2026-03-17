local M = {}

M.builtin = {
  rgbm(1, 1, 1, 1),
  rgbm(0.8, 0.8, 0.8, 1),
  rgbm(0.6, 0.6, 0.6, 1),
  rgbm(1, 0, 0, 1),
  rgbm(1, 0.5, 0, 1),
  rgbm(1, 1, 0, 1),
  rgbm(0.5, 1, 0, 1),
  rgbm(0, 1, 0, 1),
  rgbm(0, 1, 0.5, 1),
  rgbm(0, 1, 1, 1),
  rgbm(0, 0.5, 1, 1),
  rgbm(0, 0, 1, 1),
  rgbm(0.5, 0, 1, 1),
  rgbm(1, 0, 1, 1),
  rgbm(1, 0, 0.5, 1),
  rgbm(0, 0, 0, 1),
  rgbm(0.2, 0.2, 0.2, 1),
  rgbm(0.4, 0.4, 0.4, 1),
  rgbm(1, 0, 0, 1):scale(0.5),
  rgbm(1, 0.5, 0, 1):scale(0.5),
  rgbm(1, 1, 0, 1):scale(0.5),
  rgbm(0.5, 1, 0, 1):scale(0.5),
  rgbm(0, 1, 0, 1):scale(0.5),
  rgbm(0, 1, 0.5, 1):scale(0.5),
  rgbm(0, 1, 1, 1):scale(0.5),
  rgbm(0, 0.5, 1, 1):scale(0.5),
  rgbm(0, 0, 1, 1):scale(0.5),
  rgbm(0.5, 0, 1, 1):scale(0.5),
  rgbm(1, 0, 1, 1):scale(0.5),
  rgbm(1, 0, 0.5, 1):scale(0.5),
}

M.user = stringify.tryParse(ac.storage.palette) or table.range(15, function ()
  return rgbm(math.random(), math.random(), math.random(), 1)
end)

function M.addToUserPalette(color)
  local _, i = table.findFirst(M.user, function (item) return item == color end)
  if i ~= nil then
    table.remove(M.user, i)
  else
    table.remove(M.user, 1)
  end
  table.insert(M.user, color:clone())
  ac.storage.palette = stringify(M.user, true)
end

return M
