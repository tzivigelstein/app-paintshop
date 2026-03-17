local state     = require('src/state')
local shortcuts = require('src/shortcuts')
local assets    = require('src/assets')

local M = {}

-- Returns a brush size multiplier in [penMinRadiusMult, 1] based on pen pressure.
function M.brushSizeMult(brush)
  local p = ac.getPenPressure()
  if p ~= 1 and not state.stored.hasPen then state.stored.hasPen = true end
  return math.lerp(brush.penMinRadiusMult, 1, p)
end

-- Computes the "up" vector for brush projection, optionally randomizing the angle.
function M.getBrushUp(dir, tool)
  local brush = tool.brush
  return mat4x4.rotation(
    math.rad(brush.brushRandomizedAngle and tool.__brushRandomAngle or brush.brushAngle),
    dir
  ):transformVector(state.car.up)
end

-- Creates a persistent brush parameter storage block.
function M.brushParams(key, defaultSize, defaultAlpha, extraFields)
  local t = {
    brushTex            = '',
    brushSize           = defaultSize or 0.05,
    brushAspectMult     = 1,
    brushStepSize       = 0.005,
    brushAngle          = 0,
    brushRandomizedAngle = false,
    brushAlpha          = defaultAlpha or 0.5,
    brushMirror         = false,
    penMinRadiusMult    = 0.05,
    withMirror          = false,
    paintThrough        = false,
    smoothing           = 0,
  }
  if extraFields then
    for k, v in pairs(extraFields) do t[k] = v end
  end
  return ac.storage(t, key)
end

-- Renders the horizontal scrollable brush texture picker.
function M.BrushBlock(brush)
  if brush.brushTex == '' then brush.brushTex = assets.brushes[1][2] end
  local anySelected = false
  ui.childWindow('brushesList', vec2(210, 60), false,
    bit.bor(ui.WindowFlags.HorizontalScrollbar, ui.WindowFlags.AlwaysHorizontalScrollbar, ui.WindowFlags.NoBackground),
    function ()
      ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.transparent)
      for i = 1, #assets.brushes do
        local selected = assets.brushes[i][2] == brush.brushTex
        if ui.button('##b'..i, 48, selected and ui.ButtonFlags.Active or ui.ButtonFlags.None) then
          brush.brushTex = assets.brushes[i][2]
          state.selectedBrushOutlineDirty = true
        end
        if selected then anySelected = true end
        ui.addIcon(assets.brushes[i][2], 36, 0.5, nil, 0)
        if ui.itemHovered() then ui.setTooltip('Brush: '..assets.brushes[i][1]) end
        ui.sameLine(0, 4)
      end
      ui.popStyleColor()
      ui.newLine()
    end
  )
  if not anySelected then brush.brushTex = assets.brushes[1][2] end
  ui.itemPopup(function ()
    if ui.selectable('Open in Explorer') then os.openInExplorer(state.brushesDir) end
    if ui.selectable('Refresh') then assets.rescanBrushes() end
  end)
end

-- Renders all common brush sliders (size, opacity, angle, symmetry, etc.).
function M.BrushBaseBlock(brush, maxSize, stickerMode, noStepSize, noSymmetry)
  if not ui.mouseBusy() then
    local w = ui.mouseWheel()
    if ui.keyboardButtonPressed(ui.KeyIndex.SquareOpenBracket, true)  then w = w - 1 end
    if ui.keyboardButtonPressed(ui.KeyIndex.SquareCloseBracket, true) then w = w + 1 end
    if w ~= 0 then
      if state.uiState.shiftDown then w = w / 10 end
      if state.uiState.altDown then
        brush.brushAngle = brush.brushAngle + w * 30
      elseif not state.uiState.ctrlDown then
        brush.brushSize = math.clamp(brush.brushSize * (1 + w * 0.15), 0.001, maxSize)
      elseif stickerMode then
        brush.brushAspectMult = math.clamp(brush.brushAspectMult * (1 + w * 0.25), 0.04, 25)
      end
      state.selectedBrushOutlineDirty = true
    end
    for i = 0, 9 do
      if shortcuts.opacity[i]() then brush.brushAlpha = i == 0 and 1 or i / 10 end
    end
  end

  if stickerMode then
    if ui.checkbox('Flip sticker', brush.brushMirror) or shortcuts.flipSticker() then
      brush.brushMirror = not brush.brushMirror
    end
    if ui.itemHovered() then ui.setTooltip('Flip sticker (Z)') end
  end

  brush.brushSize = ui.slider('##brushSize', brush.brushSize * 100, 0.1, maxSize * 100, 'Size: %.1f cm', 2) / 100
  if ui.itemHovered() then ui.setTooltip('Use mouse wheel to quickly change size') end
  if ui.itemEdited() then state.selectedBrushOutlineDirty = true end

  if state.stored.hasPen then
    brush.penMinRadiusMult = ui.slider('##penMinRadiusMult', brush.penMinRadiusMult * 100, 0, 100, 'Minimum size: %.1f%%') / 100
    if ui.itemHovered() then ui.setTooltip('Size of a brush with minimum pen pressure') end
  end

  if stickerMode then
    ui.setNextItemWidth(ui.availableSpaceX() - 60)
    brush.brushAspectMult = ui.slider('##brushAspectMult', brush.brushAspectMult * 100, 4, 2500, 'Stretch: %.0f%%', 4) / 100
    if ui.itemHovered() then ui.setTooltip('Use mouse wheel and hold Ctrl to quickly change stretch') end
    if ui.itemEdited() then state.selectedBrushOutlineDirty = true end
    ui.sameLine(0, 4)
    if ui.button('Reset', vec2(56, 0)) then
      brush.brushAspectMult = 1
      state.selectedBrushOutlineDirty = true
    end
  end

  if not stickerMode and not noStepSize then
    brush.brushStepSize = ui.slider('##brushStepSize', brush.brushStepSize * 100, 0.1, 50, 'Step size: %.1f cm', 2) / 100
  end

  brush.brushAlpha = ui.slider('##alpha', brush.brushAlpha * 100, 0, 100, 'Opacity: %.1f%%') / 100
  if ui.itemHovered() then ui.setTooltip('Use digit buttons to quickly change opacity') end

  if ui.checkbox('##randomAngle', brush.brushRandomizedAngle) then
    brush.brushRandomizedAngle = not brush.brushRandomizedAngle
  end
  if ui.itemHovered() then ui.setTooltip('Randomize angle when drawing') end
  ui.sameLine(0, 4)
  ui.setNextItemWidth(210 - 22 - 4 - 60)
  brush.brushAngle = (brush.brushAngle % 360 + 360) % 360
  brush.brushAngle = ui.slider('##brushAngle', brush.brushAngle, 0, 360, 'Angle: %.0f\xc2\xb0')
  if ui.itemHovered() then ui.setTooltip('Use mouse wheel and hold Alt to quickly change angle') end
  ui.sameLine(0, 4)
  if ui.button('Reset##angle', vec2(56, 0)) then brush.brushAngle = 0 end

  if not stickerMode and not noStepSize then
    brush.smoothing = ui.slider('##smoothing', brush.smoothing * 100, 0, 100, 'Smoothing: %.1f%%') / 100
    if ui.itemHovered() then ui.setTooltip('Smoothing makes brush move smoother and slower') end
  end

  if not noSymmetry then
    if ui.checkbox('With symmetry', brush.withMirror) or shortcuts.toggleSymmetry() then
      brush.withMirror = not brush.withMirror
    end
    if ui.itemHovered() then ui.setTooltip('Paint with symmetry (Y)\nMirrors things from one side of a car to another') end
  end

  if ui.checkbox('Paint through', brush.paintThrough) or shortcuts.toggleDrawThrough() then
    brush.paintThrough = not brush.paintThrough
  end
  if ui.itemHovered() then ui.setTooltip('Paint through model (R)\nIf enabled, drawings would go through model and leave traces on the opposite side as well') end
end

return M
