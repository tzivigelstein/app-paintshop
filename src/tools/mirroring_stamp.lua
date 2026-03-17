local base      = require('src/tools/base')
local shortcuts = require('src/shortcuts')
local assets    = require('src/assets')
local state     = require('src/state')

return {
  name  = 'Mirroring stamp (K)',
  key   = shortcuts.toolMirroringStamp,
  icon  = assets.icons.MirroringStamp,
  brush = base.brushParams('mirroringStamp'),

  ui = function (s)
    ui.header('Mirroring stamp:')
    base.BrushBlock(s.brush)
    base.BrushBaseBlock(s.brush, 0.5, false, true, true)
  end,

  procBrushTex = function (s, ray, previewMode)
    if not s._shot then
      s._shot     = ac.GeometryShot(state.selectedMeshes, 256):setShadersType(render.ShadersType.SampleColor)
      s._ksAmbient = state.selectedMeshes:getMaterialPropertyValue('ksAmbient')
    end
    local up  = base.getBrushUp(ray.dir, s)
    state.selectedMeshes:setMaterialTexture('txDiffuse', state.editingCanvas)
    state.selectedMeshes:setMaterialProperty('ksAmbient', 1)
    s._shot:clear(table.random(rgbm.colors))
    local lpos, ldir, lup =
      state.car.worldToLocal:transformPoint(ray.pos),
      state.car.worldToLocal:transformVector(ray.dir),
      state.car.worldToLocal:transformVector(up)
    lpos.x, ldir.x, lup.x = -lpos.x, -ldir.x, -lup.x
    local ipos = state.car.bodyTransform:transformPoint(lpos)
    local idir = state.car.bodyTransform:transformVector(ldir)
    local iup  = state.car.bodyTransform:transformVector(lup)
    local brushSize = previewMode and s.brush.brushSize or s.brush.brushSize * base.brushSizeMult(s.brush)
    s._shot:setOrthogonalParams(vec2(brushSize, brushSize), 100):update(ipos, idir, iup, 0)
    state.selectedMeshes:setMaterialTexture('txDiffuse', state.aoCanvas)
    state.selectedMeshes:setMaterialProperty('ksAmbient', s._ksAmbient)
    return s._shot
  end,

  procProjParams = function (s, pr)
    pr.mask2      = s.brush.brushTex
    pr.mask2Flags = render.TextureMaskFlags.UseAlpha
  end,

  brushColor = function (s)
    return rgbm(1, 1, 1, s.brush.brushAlpha)
  end,

  brushSize = function (s)
    return vec2(-s.brush.brushSize, s.brush.brushSize)
  end,

  stickerMode        = true,
  stickerNoAlignment = true,
  stickerContinious  = true,
}
