local state = require('src/state')

local M = {}

local undoStack = {}
local redoStack = {}

function M.getUndoSize() return #undoStack end
function M.getRedoSize() return #redoStack end

function M.undoMemoryFootprint()
  return table.sum(undoStack, function (u) return u('memoryFootprint') end)
      + table.sum(redoStack, function (u) return u('memoryFootprint') end)
end

function M.addUndo(undo)
  if #undoStack > 29 then
    undoStack[1]('dispose')
    table.remove(undoStack, 1)
  end
  table.insert(undoStack, undo)
  table.clear(redoStack)
  state.changesMade = state.changesMade + 1
end

function M.stepUndo()
  local last = undoStack[#undoStack]
  if not last then return end
  table.insert(redoStack, last('update'))
  last()
  last('dispose')
  table.remove(undoStack)
  state.changesMade = state.changesMade - 1
  state.editingCanvasPhase = state.editingCanvasPhase + 1
end

function M.stepRedo()
  local last = redoStack[#redoStack]
  if not last then return end
  table.insert(undoStack, last('update'))
  last()
  last('dispose')
  table.remove(redoStack)
  state.changesMade = state.changesMade + 1
  state.editingCanvasPhase = state.editingCanvasPhase + 1
end

function M.updateAccessibleData()
  state.editingCanvasPhase = state.editingCanvasPhase + 1
  if state.accessibleData then state.accessibleData:dispose() end
  state.editingCanvas:accessData(function (err, data)
    if data then state.accessibleData = data
    elseif err then ac.warn('Failed to access canvas: '..tostring(err)) end
  end)
end

function M.clearStacks()
  undoStack = {}
  redoStack = {}
end

-- Autosave interval (runs every 20 seconds, writes only when canvas has changed)
local autosaveIndex = 1
local autosavePhase = 0

setInterval(function ()
  if not state.editingCanvas
      or autosavePhase == state.editingCanvasPhase
      or state.uiState.isMouseLeftKeyDown then
    return
  end
  autosavePhase = state.editingCanvasPhase
  io.createDir(state.autosaveDir)
  state.editingCanvas:save(
    string.format('%s/autosave-%s.zip', state.autosaveDir, autosaveIndex),
    ac.ImageFormat.ZippedDDS
  )
  autosaveIndex = autosaveIndex + 1
  if autosaveIndex > 10 then autosaveIndex = 1 end
end, 20)

return M
