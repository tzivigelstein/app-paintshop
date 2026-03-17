local state     = require('src/state')
local palette   = require('src/palette')
local shortcuts = require('src/shortcuts')
local assets    = require('src/assets')

return {
  name = 'Eyedropper (I)',
  key  = shortcuts.toolEyeDropper,
  icon = assets.icons.EyeDropper,

  ui = function (s)
    ui.header('Color:')
    require('src/ui/components').ColorBlock()
    ui.offsetCursorY(20)

    ui.header('Eyedropper:')
    ui.alignTextToFramePadding()
    ui.text('Sample size:')
    ui.sameLine()
    ui.setNextItemWidth(ui.availableSpaceX())
    state.stored.eyeDropperRange = ui.combo('##sampleSize', state.stored.eyeDropperRange, ui.ComboFlags.None, {
      'Point sample',
      '3 by 3 average',
      '5 by 5 average',
      '7 by 7 average',
      '9 by 9 average',
    })

    if s._color and not ui.mouseBusy() then
      local components = require('src/ui/components')
      components.ColorTooltip(s._color)
      if state.uiState.isMouseLeftKeyDown then
        state.stored.color = s._color
        s._changing = true
      elseif s._changing then
        s._changing = false
        palette.addToUserPalette(s._color)
      end
    end
  end,

  action = function (s)
    if state.accessibleData ~= nil then
      local ray = render.createMouseRay()
      local uv  = vec2()
      if state.selectedMeshes:raycast(ray, false, nil, nil, uv) ~= -1 then
        uv.x = uv.x - math.floor(uv.x)
        uv.y = uv.y - math.floor(uv.y)
        local c      = uv * state.accessibleData:size()
        local range  = 1 + (state.stored.eyeDropperRange - 1) * 2
        local offset = -math.ceil(range / 2)
        local cx, cy = math.floor(c.x) + offset, math.floor(c.y) + offset
        local colorPick = rgbm()
        s._color:set(colorPick)
        for x = 1, range do
          for y = 1, range do
            s._color:add(state.accessibleData:colorTo(colorPick, cx + x, cy + y))
          end
        end
        s._color:scale(1 / (range * range))
      end
    end
  end,

  _color    = rgbm(1, 1, 1, 1),
  _changing = false,
}
