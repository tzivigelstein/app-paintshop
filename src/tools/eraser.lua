local base      = require('src/tools/base')
local palette   = require('src/palette')
local shortcuts = require('src/shortcuts')
local assets    = require('src/assets')
local state     = require('src/state')

return {
  name  = 'Eraser (E)',
  key   = shortcuts.toolEraser,
  icon  = assets.icons.Eraser,
  brush = base.brushParams('eraser'),

  ui = function (s)
    ui.header('Background color:')
    require('src/ui/components').ColorBlock('bgColor')
    ui.offsetCursorY(20)
    ui.header('Eraser:')
    base.BrushBlock(s.brush)
    base.BrushBaseBlock(s.brush, 0.5)
  end,

  brushColor = function (s)
    return state.stored.bgColor
  end,

  brushSize = function (s)
    return vec2(s.brush.brushSize, s.brush.brushSize)
  end,
}
