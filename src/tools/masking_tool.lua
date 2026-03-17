local state     = require('src/state')
local masking   = require('src/masking')
local history   = require('src/history')
local shortcuts = require('src/shortcuts')
local assets    = require('src/assets')

return {
  name = 'Masking (M)',
  key  = shortcuts.toolMasking,
  icon = assets.icons.Masking,

  ui = function (s)
    if ui.checkbox('Masking is active', masking.maskingActive) then
      masking.maskingActive = not masking.maskingActive
    end
    if ui.itemHovered() then ui.setTooltip('Toggle masking (Ctrl+M)') end

    ui.textWrapped(
      'Masking tool is a plane separating model in two halves. When you draw a thing, it would only '..
      'get drawn on the side of a plane with camera. Might help in masking things quickly.\n\n'..
      'Click model and drag mouse to quickly create a new plane.\n\n'..
      'Pro tip: when using brush, hold M for more than 0.2 seconds: tool will switch to masking '..
      'temporary, so you can quickly put a mask and go back to brush by releasing M.'
    )
  end,

  action = function (s)
    local ray = render.createMouseRay()
    local d   = state.selectedMeshes:raycast(ray)
    if d ~= -1 then s._d = d end

    if d ~= -1 and state.uiState.isMouseLeftKeyClicked then
      masking.maskingCreatingFrom = state.car.worldToLocal:transformPoint(ray.pos + ray.dir * d)
      s._moving = false
    elseif masking.maskingCreatingFrom then
      if not state.uiState.isMouseLeftKeyDown then
        if s._moving then
          local endingPos = state.car.worldToLocal:transformPoint(ray.pos + ray.dir * d)
          masking.applyQuickMasking(masking.maskingCreatingFrom, endingPos)
          s._moving = false
        end
        masking.maskingCreatingFrom = nil
        masking.maskingCreatingTo   = nil
      end
      if not s._moving and #ui.mouseDragDelta() > 0 then
        history.addUndo(masking.maskingBackup())
        s._moving             = true
        masking.maskingActive = true
      end
      if s._moving then
        masking.maskingCreatingTo = state.car.worldToLocal:transformPoint(ray.pos + ray.dir * s._d)
      end
    end
  end,
}
