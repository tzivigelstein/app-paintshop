local state   = require('src/state')
local history = require('src/history')

local M = {}

-- Mutable masking plane state (exposed so masking_tool and draw3D can read/write directly)
M.maskingActive       = false
M.maskingPos          = vec3(0, 0.3, 0)
M.maskingDir          = vec3(0, 1, 0)
M.maskingCreatingFrom = nil
M.maskingCreatingTo   = nil
M.maskingDragging     = 0
M.maskingPoints       = {
  vec3(0, 0.3, -1),
  vec3(0, 0.3,  1),
  vec3(-1, 0.3, 0),
  vec3( 1, 0.3, 0),
}

local maskingDirty        = true
local maskingStartMousePos = nil

-- Recalculates maskingPos and maskingDir from the four control points.
local function fitMaskingPoints(fitFirst)
  if fitFirst then
    M.maskingDir = math.cross(M.maskingPoints[1] - M.maskingPoints[2], M.maskingPoints[4] - M.maskingPoints[3]):normalize()
    M.maskingPos = (M.maskingPoints[1] + M.maskingPoints[2]) / 2
    local ort1 = math.cross(M.maskingDir, vec3(1, 0, 0)):normalize()
    local ort2 = math.cross(M.maskingDir, vec3(0, 0, 1)):normalize()
    M.maskingPoints[3] = vec3(M.maskingPoints[3].x, M.maskingPos.y - M.maskingPos.z * ort1.y / ort1.z + ort2.y * M.maskingPoints[3].x / ort2.x, 0)
    M.maskingPoints[4] = vec3(M.maskingPoints[4].x, M.maskingPos.y - M.maskingPos.z * ort1.y / ort1.z + ort2.y * M.maskingPoints[4].x / ort2.x, 0)
  else
    M.maskingDir = math.cross(M.maskingPoints[1] - M.maskingPoints[2], M.maskingPoints[4] - M.maskingPoints[3]):normalize()
    M.maskingPos = (M.maskingPoints[3] + M.maskingPoints[4]) / 2
    local ort2 = math.cross(M.maskingDir, vec3(0, 0, 1)):normalize()
    local ort1 = math.cross(M.maskingDir, vec3(1, 0, 0)):normalize()
    M.maskingPoints[1] = vec3(0, M.maskingPos.y - M.maskingPos.x * ort2.y / ort2.x + ort1.y * M.maskingPoints[1].z / ort1.z, M.maskingPoints[1].z)
    M.maskingPoints[2] = vec3(0, M.maskingPos.y - M.maskingPos.x * ort2.y / ort2.x + ort1.y * M.maskingPoints[2].z / ort1.z, M.maskingPoints[2].z)
  end
end

function M.applyQuickMasking(from, to)
  if math.abs(from.x - to.x) < math.abs(from.z - to.z) then
    M.maskingPoints[1] = vec3(0, from.y, from.z)
    M.maskingPoints[2] = vec3(0, to.y, to.z)
    M.maskingPoints[3] = vec3(-1, 0, 0)
    M.maskingPoints[4] = vec3( 1, 0, 0)
    fitMaskingPoints(true)
  else
    M.maskingPoints[1] = vec3(0, 0, -1)
    M.maskingPoints[2] = vec3(0, 0,  1)
    M.maskingPoints[3] = vec3(from.x, from.y, 0)
    M.maskingPoints[4] = vec3(to.x,   to.y,   0)
    fitMaskingPoints(false)
  end
end

-- Returns a closure that can restore the current masking state (used as an undo entry).
function M.maskingBackup()
  local b = stringify({ M.maskingPos, M.maskingDir, M.maskingPoints }, true)
  return function (action)
    if action == 'memoryFootprint' then return 0 end
    if action == 'update' then return M.maskingBackup() end
    if action == 'dispose' then return end
    M.maskingPos, M.maskingDir, M.maskingPoints = table.unpack(stringify.parse(b))
    M.maskingActive = true
  end
end

-- Updates the maskingCanvas texture each frame based on the current plane orientation.
function M.updateMaskingCanvas()
  if not M.maskingActive then
    if state.maskingCanvas and maskingDirty then
      maskingDirty = false
      state.maskingCanvas:clear(rgbm.colors.white)
    end
    return
  end

  if not state.maskingCanvas then
    state.maskingCanvas = ui.ExtraCanvas(vec2(2048, 2048))
  end

  maskingDirty = true
  state.maskingCanvas:clear(rgbm.colors.black)
  state.maskingCanvas:update(function ()
    local mdir = M.maskingDir
    if mdir:dot(state.car.worldToLocal:transformPoint(ac.getCameraPosition()) - M.maskingPos) < 0 then
      mdir = mdir:clone():scale(-1)
    end
    local pos = M.maskingPos + mdir * 5
    local dir = math.cross(mdir, vec3(0, 0, 1))
    state.selectedMeshes:projectTexture({
      filename   = 'color::#ffffff',
      pos        = state.car.bodyTransform:transformPoint(pos),
      look       = state.car.bodyTransform:transformVector(dir),
      up         = state.car.bodyTransform:transformVector(mdir),
      color      = rgbm.colors.white,
      size       = vec2(10, 10),
      depth      = 1e9,
      doubleSided = true,
    })
  end)
end

-- Projects a ray onto one of the two car-aligned planes used for point dragging.
local function rayPlane(ray, opposite)
  local s = opposite and state.car.look or state.car.side
  return ray:plane(state.car.position, s)
end

-- Handles hit-testing and dragging of one masking control point in 3D space.
local function draggingPoint(index, point, ray)
  local pos     = state.car.bodyTransform:transformPoint(point)
  local hovered = ray:sphere(pos, 0.04) ~= -1
  render.circle(
    pos, -ac.getCameraForward(), 0.04,
    rgbm(hovered and state.sim.whiteReferencePoint or 0, state.sim.whiteReferencePoint, state.sim.whiteReferencePoint, 0.3),
    rgbm(0, state.sim.whiteReferencePoint, state.sim.whiteReferencePoint, 1)
  )
  if M.maskingDragging == 0 and state.uiState.isMouseLeftKeyClicked and hovered then
    maskingStartMousePos    = ui.projectPoint(pos)
    M.maskingDragging       = index
    state.ignoreMousePress  = true
    state.drawing           = false
    M.maskingCreatingFrom   = nil
    history.addUndo(M.maskingBackup())
  elseif M.maskingDragging == index then
    maskingStartMousePos:add(state.uiState.mouseDelta)
    local r = render.createPointRay(maskingStartMousePos)
    local d = rayPlane(r, index > 2)
    if d ~= -1 then
      point:set(state.car.worldToLocal:transformPoint(r.pos + r.dir * d))
    end
  end
end

-- Called from script.draw3D in the entry point.
function M.draw3D()
  if not state.appVisible or not state.selectedMeshes or not M.maskingActive then return end

  if M.maskingCreatingFrom ~= nil and M.maskingCreatingTo ~= nil then
    M.applyQuickMasking(M.maskingCreatingFrom, M.maskingCreatingTo)
    render.circle(
      state.car.bodyTransform:transformPoint(M.maskingPos),
      state.car.bodyTransform:transformVector(M.maskingDir),
      3, rgbm(state.sim.whiteReferencePoint, 0, 0, 0.1)
    )
    return
  end

  render.circle(
    state.car.bodyTransform:transformPoint(M.maskingPos),
    state.car.bodyTransform:transformVector(M.maskingDir),
    3, rgbm(state.sim.whiteReferencePoint, 0, 0, 0.3)
  )

  local ray = render.createMouseRay()
  if not ui.mouseDown() then M.maskingDragging = 0 end
  render.setDepthMode(render.DepthMode.Off)
  draggingPoint(1, M.maskingPoints[1], ray)
  draggingPoint(2, M.maskingPoints[2], ray)
  draggingPoint(3, M.maskingPoints[3], ray)
  draggingPoint(4, M.maskingPoints[4], ray)

  if M.maskingDragging == 1 or M.maskingDragging == 2 then
    fitMaskingPoints(true)
  elseif M.maskingDragging == 3 or M.maskingDragging == 4 then
    fitMaskingPoints(false)
  end
end

return M
