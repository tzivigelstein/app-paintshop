local state  = require('src/state')
local canvas = require('src/canvas')

local M = {}

local hoveredMaterial = nil
local carPreview      = nil  ---@type ac.GeometryShot

-- Renders the mesh-selection screen shown before an editing session begins.
-- The user hovers over car geometry; Shift+Click starts painting on that material.
function M.render()
  local ray = render.createMouseRay()
  local ref = ac.emptySceneReference()

  if state.sim.isWindowForeground and state.carMeshes:raycast(ray, ref) ~= -1 then
    ui.text('Found:')
    ui.pushFont(ui.Font.Small)
    ui.text('\tMesh: '     ..tostring(ref:name()))
    ui.text('\tMaterial: ' ..tostring(ref:materialName()))
    local texName = ref:getTextureSlotFilename('txDiffuse')
    ui.text('\tTexture: '  ..tostring(texName))
    ui.popFont()
    ui.offsetCursorY(20)

    if hoveredMaterial ~= ref:materialName() then
      hoveredMaterial = ref:materialName()
      if carPreview then carPreview:dispose() end
      carPreview = ac.GeometryShot(
        state.carNode:findMeshes('{ material:'..hoveredMaterial..' & lod:A }'),
        vec2(420, 320)
      )
      carPreview:setClearColor(rgbm(0.14, 0.14, 0.14, 1))
    end

    local mat = mat4x4.rotation(ui.time() * 0.1, vec3(0, 1, 0)):mul(state.car.bodyTransform)
    carPreview:update(
      mat:transformPoint(state.car.aabbCenter + vec3(0, 2, 4)),
      mat:transformVector(vec3(0, -1, -2)),
      nil, 50
    )
    ui.image(carPreview, vec2(210, 160))
    ui.offsetCursorY(20)

    local size = ui.imageSize(texName)

    if size.x > 0 and size.y > 0 then
      ui.textWrapped(
        '\xe2\x80\xa2 Hold Shift and click to start drawing.\n'..
        '\xe2\x80\xa2 Hold Ctrl+Shift and click to start drawing using custom AO map.'
      )
      ui.offsetCursorY(20)
      ui.pushFont(ui.Font.Small)
      ui.textWrapped('For best results, either use a custom AO map or make sure this texture is an AO map (grayscale colors with nothing but shadows).')
      ui.popFont()

      ui.setShadingOffset(1, 0, 1, 1)
      ui.image(texName, vec2(210, 210 * size.y / size.x))
      ui.resetShadingOffset()

      if state.uiState.shiftDown and not state.uiState.altDown
          and state.uiState.isMouseLeftKeyClicked and not state.uiState.wantCaptureMouse then
        if state.uiState.ctrlDown then
          local _meshes  = state.carNode:findMeshes('{ material:'..hoveredMaterial..' & lod:A }')
          local _texture = texName
          os.openFileDialog({
            title    = 'Open Base AO Map',
            folder   = state.carDir,
            fileTypes = { { name = 'Images', mask = '*.png;*.jpg;*.jpeg;*.dds' } },
            addAllFilesFileType = true,
            flags    = bit.bor(os.DialogFlags.PathMustExist, os.DialogFlags.FileMustExist),
          }, function (err, filename)
            if not err and filename then
              state.selectedMeshes = _meshes
              state.carTexture     = _texture
              state.aoTexture      = filename
              state.camera         = ac.grabCamera('Paintshop')
              if state.camera then state.camera.ownShare = 0 end
            end
          end)
        else
          state.selectedMeshes = state.carNode:findMeshes('{ material:'..hoveredMaterial..' & lod:A }')
          state.carTexture     = texName
          state.aoTexture      = nil
          state.camera         = ac.grabCamera('Paintshop')
          if state.camera then state.camera.ownShare = 0 end
        end
      end
    else
      ui.text('Texture is missing')
    end
  else
    ui.text('Hover a car mesh to start drawing\xe2\x80\xa6')
  end
end

return M
