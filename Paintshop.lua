local state   = require('src/state')
local canvas  = require('src/canvas')
local camera  = require('src/camera')
local painting = require('src/painting')
local masking = require('src/masking')
local tools   = require('src/tools/init')
local assets  = require('src/assets')
local meshSel = require('src/ui/mesh_selector')
local editor  = require('src/ui/skin_editor')

-- Initialize pen/stylus API and set the active tool from persisted index
ac.getPenPressure()
tools.init()

-- Restore the original car texture if the script is unloaded mid-session
ac.onRelease(function ()
  canvas.restoreOriginalTexture()
end)

function script.update(dt)
  if not state.appVisible then
    camera.dispose()
    return
  end
  if state.selectedMeshes ~= nil then
    camera.update()
  end
end

function script.onWorldUpdate(dt)
  if state.appVisible and state.selectedMeshes ~= nil then
    ui.setAsynchronousImagesLoading(false)
    painting.update()
  end
end

function script.draw3D()
  masking.draw3D()
end

function script.windowMain(dt)
  if assets.brushes == nil then
    assets.rescanBrushes()
    assets.rescanStickers()
  end

  ui.pushItemWidth(210)
  ui.setAsynchronousImagesLoading(true)

  if state.selectedMeshes == nil then
    meshSel.render()
  else
    editor.render()
  end

  ui.popItemWidth()

  if state.debugTex then
    ui.setShadingOffset(1, 0, 1, 1)
    ui.image(state.debugTex, 210, rgbm.colors.white, rgbm.colors.red)
    ui.resetShadingOffset()
  end
end

function script.onShowWindowMain()
  state.appVisible = true
end

function script.onHideWindowMain()
  state.appVisible = false
  if state.selectedMeshes == nil then
    setTimeout(ac.unloadApp, 1)
  end
end
