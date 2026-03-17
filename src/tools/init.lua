local state = require('src/state')

-- Load all tool definitions in the canonical display order
local toolDefs = {
  require('src/tools/brush'),
  require('src/tools/eraser'),
  require('src/tools/stamp'),
  require('src/tools/mirroring_stamp'),
  require('src/tools/blur'),
  require('src/tools/text'),
  require('src/tools/masking_tool'),
  require('src/tools/eyedropper'),
}

local M = {}

-- Called once from the entry point after all modules are loaded.
-- Populates state.activeTool from the persisted index.
function M.init()
  local idx = math.clamp(state.stored.activeToolIndex, 1, #toolDefs)
  state.activeTool        = toolDefs[idx]
  state.previousToolIndex = idx
end

function M.getTools()
  return toolDefs
end

function M.getActiveTool()
  return state.activeTool
end

function M.setActiveTool(tool, index)
  state.previousToolIndex = state.stored.activeToolIndex
  state.activeTool        = tool
  state.stored.activeToolIndex = index
  state.selectedBrushOutlineDirty = true
end

function M.restorePreviousTool()
  local prev = toolDefs[state.previousToolIndex]
  if prev then
    state.activeTool             = prev
    state.stored.activeToolIndex = state.previousToolIndex
    state.selectedBrushOutlineDirty = true
  end
end

return M
