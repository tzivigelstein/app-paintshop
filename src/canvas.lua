local state   = require('src/state')
local history = require('src/history')

local M = {}

-- Lazily creates editingCanvas and aoCanvas on first call after a mesh is selected.
-- Called from camera.update() so the canvases are ready before the first paint frame.
function M.ensure()
  if state.editingCanvas ~= nil then return end
  state.editingCanvas = ui.ExtraCanvas(vec2(2048, 2048)):clear(rgbm.new(state.stored.bgColor.rgb, 1))
  state.aoBaseCanvas  = ui.ExtraCanvas(vec2(2048, 2048))
  state.aoCanvas      = ui.ExtraCanvas(vec2(2048, 2048), 4, render.AntialiasingMode.CMAA)
  state.selectedMeshes:setMaterialTexture('txDiffuse', state.aoCanvas)
end

-- Restores the original car texture on the mesh. Used in ac.onRelease to clean up
-- if the app is unloaded while an editing session is in progress.
function M.restoreOriginalTexture()
  if state.carTexture and state.selectedMeshes then
    state.selectedMeshes
      :setMaterialTexture('txDiffuse', state.carTexture)
      :setMotionStencil(state.taaFix.Off)
  end
end

-- Resets all canvas and session state without touching the camera.
-- Called by finishEditing() in skin_editor before camera.releaseSmooth().
function M.clearSession()
  state.editingCanvas      = nil
  state.aoBaseCanvas       = nil
  state.aoCanvas           = nil
  state.maskingCanvas      = nil
  state.accessibleData     = nil
  state.editingCanvasPhase = 0
  state.selectedMeshes     = nil
  state.carTexture         = nil
  state.aoTexture          = nil
  state.saveFilename       = nil
  state.changesMade        = 0
  state.drawing            = false
  state.ignoreMousePress   = true
  state.selectedBrushOutlineDirty = true
  history.clearStacks()
  ac.setWindowTitle('paintshop', nil)
end

return M
