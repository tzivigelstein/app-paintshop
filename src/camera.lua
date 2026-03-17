local state  = require('src/state')
local canvas = require('src/canvas')

local M = {}

-- Constant vec3 literals hoisted to avoid per-frame allocation.
local _axisX   = vec3(1, 0, 0)
local _axisY   = vec3(0, 1, 0)
local _lookFwd = vec3(0, 0, 1)
local _lookUp  = vec3(0, 1, 0)

-- Called every frame while a mesh session is active.
-- Ensures canvases exist, then updates orbit camera position and input.
function M.update()
  canvas.ensure()

  local cam = state.camera
  if cam then
    local mat = mat4x4.rotation(state.cameraAngle.y, _axisX)
      :mul(mat4x4.rotation(state.cameraAngle.x, _axisY))
      :mul(state.car.bodyTransform)

    cam.transform.position = mat:transformPoint(
      vec3(0, state.car.aabbCenter.y * math.smoothstep(math.lerpInvSat(state.cameraAngle.y, 0.5, 0)), -8)
    )
    cam.transform.look = mat:transformVector(_lookFwd)
    cam.transform.up   = mat:transformVector(_lookUp)
    cam.fov = 24

    cam.ownShare = math.applyLag(cam.ownShare, state.stored.orbitCamera and 1 or 0, 0.85, ac.getDeltaT())

    if state.stored.orbitCamera
        and (ui.keyboardButtonDown(ui.KeyIndex.Space) or ui.mouseDown(ui.MouseButton.Middle)) then
      state.cameraAngle:add(state.uiState.mouseDelta * vec2(-0.003, 0.003))
    end

    if not state.stored.orbitCamera and cam.ownShare < 0.001 then
      cam:dispose()
      state.camera = nil
    end
  elseif state.stored.orbitCamera then
    state.camera = ac.grabCamera('Paintshop')
    if state.camera then state.camera.ownShare = 0 end
  end
end

-- Immediately releases the camera (used when the app window is hidden).
function M.dispose()
  if state.camera then
    state.camera:dispose()
    state.camera = nil
  end
end

-- Gradually fades out ownShare to 0, then disposes. Used after finishing an editing session.
function M.releaseSmooth()
  if not state.camera then return end
  local cam = state.camera
  local handle
  handle = setInterval(function ()
    cam.ownShare = math.applyLag(cam.ownShare, 0, 0.85, ac.getDeltaT())
    if cam.ownShare < 0.001 then
      clearInterval(handle)
      cam:dispose()
      if state.camera == cam then state.camera = nil end
    end
  end)
end

return M
