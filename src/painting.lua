local state   = require('src/state')
local masking = require('src/masking')
local ao      = require('src/ao')
local base    = require('src/tools/base')
local history = require('src/history')

local M = {}

-- Persistent surface-alignment state used across frames
local pdistance = 1
local pnormal   = vec3()
local pdir      = vec3(1, 0, 0)

-- Projects a brush/sticker texture onto the editing canvas at the given world position.
function M.projectBrushTexture(tex, pos, dir, color, distance, previewMode, doNotUseToolProjParams)
  local tool  = state.activeTool
  local brush = tool.brush
  if not brush then return end

  if tool.stickerMode and not tool.stickerNoAlignment and state.stored.alignSticker > 1 then
    local d, m = state.selectedMeshes:raycast(render.createRay(pos, dir), true, nil, pnormal)
    if d ~= -1 then
      pdir      = m:getWorldTransformationRaw():transformVector(pnormal):scale(-1)
      pdistance = d
    else
      d = pdistance
    end
    pos = pos + dir * d
    dir = pdir:clone()
    if state.stored.alignSticker == 3 then
      dir = dir - state.car.up * dir:dot(state.car.up)
    end
    distance = 0.2
  end

  local size = tool:brushSize()
  if not previewMode and (not tool.stickerMode or tool.stickerContinious) then
    size = size * base.brushSizeMult(brush)
  end
  if brush.brushAspectMult > 1 then size.x = size.x * brush.brushAspectMult
  else size.y = size.y / brush.brushAspectMult end
  if brush.brushMirror then size.x = -size.x end

  if not tool.__brushRandomAngle or previewMode then
    tool.__brushRandomAngle = brush.brushAngle
  else
    tool.__brushRandomAngle = math.random() * 360
  end

  local up = base.getBrushUp(dir, tool)
  local pr = {
    filename    = tex,
    pos         = pos,
    look        = dir,
    up          = up,
    color       = color,
    size        = size,
    depth       = brush.paintThrough and 1e9 or distance,
    doubleSided = brush.paintThrough,
    mask1       = state.maskingCanvas,
    mask1Flags  = bit.bor(render.TextureMaskFlags.AltUV, render.TextureMaskFlags.Default),
    blendMode   = not previewMode and tool.blendMode or nil,
  }
  if tool.procProjParams and not doNotUseToolProjParams then tool:procProjParams(pr) end
  state.selectedMeshes:projectTexture(pr)

  if brush.withMirror then
    local lpos = state.car.worldToLocal:transformPoint(pos)
    local ldir = state.car.worldToLocal:transformVector(dir)
    local lup  = state.car.worldToLocal:transformVector(up)
    lpos.x, ldir.x, lup.x = -lpos.x, -ldir.x, -lup.x
    pr.pos, pr.look, pr.up = state.car.bodyTransform:transformPoint(lpos),
                             state.car.bodyTransform:transformVector(ldir),
                             state.car.bodyTransform:transformVector(lup)
    pr.size.x = -pr.size.x
    state.selectedMeshes:projectTexture(pr)
  end
end

-- Regenerates the brush outline cursor canvas (the ring shown under the mouse).
local function updateBrushOutline(stickerMode)
  if not state.selectedBrushOutline then
    state.selectedBrushOutline = ui.ExtraCanvas(vec2(128, 128), 4)
  end
  state.selectedBrushOutlineDirty = false
  local tool = state.activeTool
  if not tool or not tool.brush or stickerMode then
    state.selectedBrushOutline:clear(rgbm.colors.transparent)
    return
  end
  state.selectedBrushOutline:clear(rgbm.colors.black)
  state.selectedBrushOutline:update(function ()
    ui.renderShader({
      p1        = vec2(0, 0),
      p2        = vec2(128, 128),
      blendMode = render.BlendMode.Opaque,
      textures  = { txBrush = tool.brush.brushTex },
      values    = { gMargin = (0.5 / 128) / tool.brush.brushSize },
      shader = [[float4 main(PS_IN pin) {
        float tx = txBrush.Sample(samLinearBorder0, pin.Tex + float2(gMargin,  gMargin)).w
                 + txBrush.Sample(samLinearBorder0, pin.Tex + float2(gMargin, -gMargin)).w
                 + txBrush.Sample(samLinearBorder0, pin.Tex + float2(-gMargin, gMargin)).w
                 + txBrush.Sample(samLinearBorder0, pin.Tex + float2(-gMargin,-gMargin)).w;
        tx = saturate(tx * 20 - 1);
        tx *= 1 - saturate(txBrush.Sample(samLinear, pin.Tex).w * 20 - 1);
        return float4(1, 1, 1, tx);
      }]],
    })
  end)
end

-- Other-side projection state (used when stored.projectOtherSide is true)
local otherSideShot  ---@type ac.GeometryShot
local otherSidePhase = -1
local otherSideSide  = 0
local bakKsAmbient

-- Composites editingCanvas + AO, adds other-side ghost projection and brush cursor preview.
local function updateAOCanvas()
  if state.aoCanvas == nil then return end
  local tool = state.activeTool
  local projectDir

  if state.stored.projectOtherSide then
    if not otherSideShot then
      bakKsAmbient = state.selectedMeshes:getMaterialPropertyValue('ksAmbient')
      otherSideShot = ac.GeometryShot(state.selectedMeshes, 2048)
        :setOrthogonalParams(vec2(6, 4), 10)
        :setClippingPlanes(-10, 0)
        :setShadersType(render.ShadersType.SampleColor)
    end
    projectDir = state.car.side
    local s = math.sign(projectDir:dot(ac.getCameraForward()))
    if s > 0 then projectDir = -projectDir end
    if s ~= otherSideSide then otherSidePhase, otherSideSide = -1, s end
    if otherSidePhase ~= state.editingCanvasPhase then
      otherSidePhase = state.editingCanvasPhase
      state.selectedMeshes:setMaterialTexture('txDiffuse', state.editingCanvas)
      state.selectedMeshes:setMaterialProperty('ksAmbient', 1)
      otherSideShot:update(state.car.position, projectDir, state.car.up, 0)
      state.selectedMeshes:setMaterialTexture('txDiffuse', state.aoCanvas)
      state.selectedMeshes:setMaterialProperty('ksAmbient', bakKsAmbient)
    end
  end

  local ray = render.createMouseRay()
  local tex
  if tool and tool.stickerMode then
    tex = tool.procBrushTex and tool:procBrushTex(ray, true) or tool.brush.brushTex
  end

  if state.selectedBrushOutlineDirty then
    updateBrushOutline(tool and tool.stickerMode and tex ~= nil)
  end

  state.aoCanvas:update(function ()
    ao.drawWithAO(state.editingCanvas, state.aoTexture or state.carTexture)

    if state.stored.projectOtherSide then
      state.selectedMeshes:projectTexture({
        filename    = otherSideShot,
        pos         = state.car.position,
        look        = -projectDir,
        up          = state.car.up,
        color       = rgbm(1, 1, 1, 0.1),
        size        = vec2(-6, 4),
        depth       = 1e9,
        doubleSided = false,
      })
    end

    if tex then
      M.projectBrushTexture(tex, ray.pos, ray.dir, tool:brushColor() * rgbm(1, 1, 1, 0.3), nil, true)
    else
      M.projectBrushTexture(
        state.selectedBrushOutline, ray.pos, ray.dir,
        rgbm.colors.gray, nil, true,
        tool and tool.stickerMode
      )
    end
  end)
end

-- Main paint loop — called every world update frame while editing.
function M.update()
  local tool = state.activeTool
  if tool and tool.brush then
    if state.uiState.isMouseLeftKeyDown then
      if state.drawing then
        local ray   = render.createMouseRay()
        local brush = tool.brush
        local tex   = tool.procBrushTex and tool:procBrushTex(ray, false) or brush.brushTex
        state.editingCanvas:update(function ()
          local lastBrushDistance = state.brushDistance
          local hitDistance       = state.selectedMeshes:raycast(ray)
          if hitDistance ~= -1 then state.brushDistance = hitDistance end

          if tool.stickerMode then
            M.projectBrushTexture(tex, ray.pos, ray.dir, tool:brushColor(), state.brushDistance)
            if not tool.stickerContinious then
              setTimeout(history.updateAccessibleData)
              state.drawing = false
              state.selectedMeshes:setMotionStencil(state.taaFix.Off)
              state.ignoreMousePress = true
            end
            return
          elseif state.lastRay then
            local color = tool:brushColor()
            if brush.smoothing > 0 then
              state.smoothRayDir = math.applyLag(state.smoothRayDir, ray.dir, brush.smoothing ^ 0.3 * 0.9, 0.02)
              ray.dir:set(state.smoothRayDir)
            end
            local distance = ray.pos:clone():addScaled(ray.dir, state.brushDistance)
              :distance(state.lastRay.pos:clone():addScaled(state.lastRay.dir, lastBrushDistance))
            if distance > brush.brushStepSize then
              local steps = math.min(100, math.floor(0.5 + distance / brush.brushStepSize))
              for i = 1, steps do
                local p = math.lerp(state.lastRay.pos, ray.pos, i / steps)
                local d = math.lerp(state.lastRay.dir, ray.dir, i / steps)
                M.projectBrushTexture(tex, p, d, color, math.lerp(lastBrushDistance, state.brushDistance, i / steps))
              end
              state.lastRay = ray
            end
          else
            M.projectBrushTexture(tex, ray.pos, ray.dir, tool:brushColor(), state.brushDistance)
            state.lastRay = ray
          end
          state.smoothRayDir = ray.dir:clone()
        end)
      elseif not state.ignoreMousePress then
        state.ignoreMousePress = ui.mouseBusy()
        if not state.ignoreMousePress then
          state.drawing = true
          state.selectedMeshes:setMotionStencil(state.taaFix.On)
          if not state.uiState.shiftDown then state.lastRay = nil end
          setTimeout(function ()
            -- Delay undo registration by one frame so mask dragging can cancel it
            if state.drawing then history.addUndo(state.editingCanvas:backup()) end
          end)
        end
      end
    else
      if state.drawing then
        history.updateAccessibleData()
        state.selectedMeshes:setMotionStencil(state.taaFix.Off)
        state.drawing = false
      end
      state.ignoreMousePress = false
    end
  elseif tool and tool.action then
    tool:action()
  end

  masking.updateMaskingCanvas()
  updateAOCanvas()
end

return M
