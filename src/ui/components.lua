local state     = require('src/state')
local palette   = require('src/palette')
local shortcuts = require('src/shortcuts')

local M = {}

function M.IconButton(icon, tooltip, active, enabled)
  local flags = enabled == false and ui.ButtonFlags.Disabled
             or active            and ui.ButtonFlags.Active
             or ui.ButtonFlags.None
  local r = ui.button('##'..tostring(icon), vec2(32, 32), flags)
  ui.addIcon(icon, 24, 0.5, nil, 0)
  if tooltip and ui.itemHovered() then ui.setTooltip(tooltip) end
  return r
end

function M.ColorTooltip(color)
  ui.tooltip(0, function ()
    ui.dummy(20)
    ui.drawRectFilled(0, 20, color)
    ui.drawRect(0, 20, rgbm.colors.black)
  end)
end

local editing = false
local colorFlags = bit.bor(
  ui.ColorPickerFlags.NoAlpha,
  ui.ColorPickerFlags.NoSidePreview,
  ui.ColorPickerFlags.PickerHueWheel,
  ui.ColorPickerFlags.DisplayHex
)

function M.ColorBlock(key)
  key = key or 'color'
  local col = state.stored[key]:clone()
  ui.colorPicker('##color', col, colorFlags)
  if ui.itemEdited() then
    state.stored[key] = col
    editing = true
  elseif editing and not ui.itemActive() then
    editing = false
    palette.addToUserPalette(col)
  end

  for i = 1, #palette.builtin do
    ui.drawRectFilled(ui.getCursor(), ui.getCursor() + 14, palette.builtin[i])
    if ui.invisibleButton(i, 14) then
      state.stored[key] = palette.builtin[i]:clone()
      palette.addToUserPalette(state.stored[key])
    end
    if ui.itemHovered() then M.ColorTooltip(palette.builtin[i]) end
    ui.sameLine(0, 0)
    if ui.availableSpaceX() < 14 then ui.newLine(0) end
  end

  for i = 1, #palette.user do
    ui.drawRectFilled(ui.getCursor(), ui.getCursor() + 14, palette.user[i])
    if ui.invisibleButton(100 + i, 14) then
      state.stored[key] = palette.user[i]:clone()
      palette.addToUserPalette(state.stored[key])
    end
    if ui.itemHovered() then M.ColorTooltip(palette.user[i]) end
    ui.sameLine(0, 0)
  end

  ui.newLine()

  if shortcuts.swapColors() then
    state.stored[key] = state.stored[key] == palette.user[#palette.user]
      and palette.user[#palette.user - 1]
      or  palette.user[#palette.user]
    palette.addToUserPalette(state.stored[key])
  end
end

return M
