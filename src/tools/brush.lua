local base      = require('src/tools/base')
local palette   = require('src/palette')
local shortcuts = require('src/shortcuts')
local assets    = require('src/assets')
local state     = require('src/state')

return {
  name  = 'Brush (B)',
  key   = shortcuts.toolBrush,
  icon  = assets.icons.Brush,
  brush = base.brushParams('brush'),

  ui = function (s)
    ui.header('Color:')
    require('src/ui/components').ColorBlock()
    ui.offsetCursorY(20)
    ui.header('Brush:')
    base.BrushBlock(s.brush)
    base.BrushBaseBlock(s.brush, 0.5)
  end,

  brushColor = function (s)
    return rgbm.new(state.stored.color.rgb, s.brush.brushAlpha)
  end,

  brushSize = function (s)
    return vec2(s.brush.brushSize, s.brush.brushSize)
  end,
}
