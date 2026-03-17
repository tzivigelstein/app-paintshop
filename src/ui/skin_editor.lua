local state     = require('src/state')
local history   = require('src/history')
local canvas    = require('src/canvas')
local camera    = require('src/camera')
local tools     = require('src/tools/init')
local assets    = require('src/assets')
local shortcuts = require('src/shortcuts')
local masking   = require('src/masking')
local comp      = require('src/ui/components')

local M = {}

-- Cached window title — avoids string.gsub + ac.setWindowTitle overhead every frame.
local cachedTitle = nil

-- Ends the current editing session: restores original texture, smoothly releases
-- the camera, and resets all session state.
function M.finishEditing()
  if state.selectedMeshes then
    state.selectedMeshes
      :setMaterialTexture('txDiffuse', state.carTexture)
      :setMotionStencil(state.taaFix.Off)
  end
  cachedTitle = nil
  camera.releaseSmooth()
  canvas.clearSession()
end

-- Top toolbar: Undo, Redo, Open/Import, Save/Save-as, Export, Finish.
local function DrawControl()
  local newTitle = string.gsub(state.saveFilename or (state.carTexture..' (new)'), '.+[/\\:]', '')
    ..(state.changesMade ~= 0 and '*' or '')
  if newTitle ~= cachedTitle then
    cachedTitle = newTitle
    ac.setWindowTitle('paintshop', newTitle)
  end

  local IconButton = comp.IconButton

  -- Undo
  if IconButton(assets.icons.Undo, nil, false, history.getUndoSize() > 0)
      or history.getUndoSize() > 0 and shortcuts.undo() then
    history.stepUndo()
  end
  if ui.itemHovered() then
    ui.setTooltip(string.format('Undo (Ctrl+Z) \xe2\x80\x94 %d steps, %d MB used',
      history.getUndoSize(), math.ceil(history.undoMemoryFootprint() / (1024 * 1024))))
  end

  ui.sameLine(0, 4)

  -- Redo
  if IconButton(assets.icons.Redo,
      string.format('Redo (Ctrl+Y) \xe2\x80\x94 %d steps', history.getRedoSize()),
      false, history.getRedoSize() > 0)
      or history.getRedoSize() > 0 and shortcuts.redo() then
    history.stepRedo()
  end

  ui.sameLine(0, 4)

  -- Open / Import
  if IconButton(assets.icons.Open,
      'Load image (Ctrl+O)\n\nChoose an image without ambient occlusion, preferably one saved earlier with "Save" button of this tool.\n\nIf you accidentally forgot to save or a crash happened, there are some automatically saved backups\nin "Documents/Assetto Corsa"/cfg/apps/paintshop/autosave".\n\n(There is also an "Import" option in context menu of this button to add a semi-transparent image on top\nof current one.)')
      or shortcuts.load() then
    os.openFileDialog({
      title     = 'Open',
      folder    = state.skinDir,
      fileTypes = { { name = 'Images', mask = '*.png;*.jpg;*.jpeg;*.dds' } },
    }, function (err, filename)
      if not err and filename then
        ui.setAsynchronousImagesLoading(false)
        history.addUndo(state.editingCanvas:backup())
        state.editingCanvas:clear(rgbm.new(state.stored.bgColor.rgb, 1)):update(function ()
          ui.unloadImage(filename)
          ui.drawImage(filename, 0, ui.windowSize())
        end)
        setTimeout(history.updateAccessibleData)
        if not filename:lower():match('%.dds$') then
          state.saveFilename = filename
        end
        state.changesMade = 0
      end
    end)
  end

  ui.itemPopup('openMenu', function ()
    if ui.selectable('Clear canvas') then
      history.addUndo(state.editingCanvas:backup())
      state.editingCanvas:clear(rgbm.new(state.stored.bgColor.rgb, 1))
    end
    if ui.itemHovered() then ui.setTooltip('Clears canvas using background (eraser) color') end

    if ui.selectable('Import\xe2\x80\xa6') then
      os.openFileDialog({
        title     = 'Import',
        folder    = state.skinDir,
        fileTypes = { { name = 'Images', mask = '*.png;*.jpg;*.jpeg;*.dds' } },
      }, function (err, filename)
        if not err and filename then
          ui.setAsynchronousImagesLoading(false)
          history.addUndo(state.editingCanvas:backup())
          state.editingCanvas:update(function ()
            ui.unloadImage(filename)
            ui.drawImage(filename, 0, ui.windowSize())
          end)
          setTimeout(history.updateAccessibleData)
        end
      end)
    end

    if state.autosaveDir and ui.selectable('Open autosaves folder') then
      io.createDir(state.autosaveDir)
      os.openInExplorer(state.autosaveDir)
    end
  end)

  ui.sameLine(0, 4)

  -- Save
  local function doSave(filename)
    state.editingCanvas:save(filename)
    state.saveFilename = filename
    state.changesMade  = 0
  end

  local function openSaveDialog(title)
    os.saveFileDialog({
      title            = title,
      folder           = state.skinDir,
      fileTypes        = { { name = 'PNG', mask = '*.png' }, { name = 'JPEG', mask = '*.jpg;*.jpeg' } },
      fileName         = state.carTexture and string.gsub(state.carTexture, '.+[/\\:]', ''):gsub('%.[a-zA-Z]+$', '.png'),
      defaultExtension = 'png',
    }, function (err, filename)
      if not err and filename then doSave(filename) end
    end)
  end

  if IconButton(assets.icons.Save,
      'Save image (Ctrl+S)\n\nImage saved like that would not have antialiasing or ambient occlusion. To apply texture, use "Export texture"\nbutton on the right.\n\n(There is also a "Save as" option in context menu of this button.)')
      or shortcuts.save() then
    if state.saveFilename ~= nil then
      state.editingCanvas:save(state.saveFilename)
      state.changesMade = 0
    else
      openSaveDialog('Save Image')
    end
  end

  ui.itemPopup('saveMenu', function ()
    if ui.selectable('Save as\xe2\x80\xa6') then openSaveDialog('Save Image As') end
    if state.autosaveDir and ui.selectable('Open autosaves folder') then
      io.createDir(state.autosaveDir)
      os.openInExplorer(state.autosaveDir)
    end
  end)

  ui.sameLine(0, 4)

  -- Export
  if IconButton(assets.icons.Export,
      'Export texture (Ctrl+Shift+Alt+S)\n\nImage saved like that is ready to use, with ambient occlusion and everything. To save an intermediate\nresult and continue working on it later, use "Save" button on the left.')
      or shortcuts.export() then
    os.saveFileDialog({
      title            = 'Export Texture',
      folder           = state.skinDir,
      fileTypes        = {
        { name = 'PNG',  mask = '*.png' },
        { name = 'JPEG', mask = '*.jpg;*.jpeg' },
        { name = 'DDS',  mask = '*.dds' },
      },
      fileName         = state.carTexture and string.gsub(state.carTexture, '.+[/\\:]', ''),
      fileTypeIndex    = 3,
      defaultExtension = 'dds',
    }, function (err, filename)
      if not err and filename then
        local ao = require('src/ao')
        state.aoCanvas:update(function ()
          ao.drawWithAO(state.editingCanvas, state.aoTexture or state.carTexture)
        end):save(filename)
      end
    end)
  end

  ui.sameLine(0, 4)

  -- Finish / Cancel
  if IconButton(ui.Icons.Leave,
      state.changesMade == 0 and 'Finish editing'
        or 'Cancel editing\nThere are some unsaved changes') then
    if state.changesMade ~= 0 then
      ui.modalPopup('Cancel editing', 'Are you sure to exit without saving changes?', function (okPressed)
        if okPressed then M.finishEditing() end
      end)
    else
      M.finishEditing()
    end
  end
end

-- Full skin-editor panel (tool picker + active tool UI).
function M.render()
  DrawControl()
  if state.selectedMeshes == nil then return end

  ui.offsetCursorY(20)
  ui.header('Tools:')

  local toolList = tools.getTools()
  for i = 1, #toolList do
    local v  = toolList[i]
    local isActive = state.activeTool == v
    local holdActive = isActive and state.toolSwitched ~= 0 and ui.time() > state.toolSwitched + 0.2
    local bg = holdActive and rgbm(0.5, 0.5, 0, 1)
           or (isActive and state.uiState.accentColor * rgbm(1, 1, 1, 0.5))
    if bg then ui.pushStyleColor(ui.StyleColor.Button, bg) end
    if comp.IconButton(v.icon, v.name, isActive) or v.key and v.key(false) then
      tools.setActiveTool(v, i)
      state.toolSwitched = v.key and tonumber(ui.time()) or 0
    end
    if bg then ui.popStyleColor() end
    ui.sameLine(0, 4)
    if ui.availableSpaceX() < 12 then ui.newLine(4) end
  end

  -- Orbit camera toggle
  if comp.IconButton(assets.icons.Camera,
      'Orbit camera (Ctrl+Space)\nUse middle mouse button or hold space to rotate camera',
      state.stored.orbitCamera) or shortcuts.toggleOrbitCamera() then
    state.stored.orbitCamera = not state.stored.orbitCamera
  end
  ui.sameLine(0, 4)
  if ui.availableSpaceX() < 32 then ui.newLine(4) end

  -- Project other side toggle
  if comp.IconButton(assets.icons.MirroringHelper,
      'Project other side (Ctrl+E)\nProject other side on current side to make making things symmetrical easier',
      state.stored.projectOtherSide) or shortcuts.toggleProjectOtherSide() then
    state.stored.projectOtherSide = not state.stored.projectOtherSide
  end

  ui.offsetCursorY(20)

  -- Handle momentary tool-hold: if key was held briefly, revert to previous tool
  if state.toolSwitched ~= 0 and state.activeTool.key and not state.activeTool.key:down() then
    if ui.time() > state.toolSwitched + 0.2 then
      tools.restorePreviousTool()
      state.toolSwitched = 0
    else
      state.toolSwitched = 0
    end
  end

  if shortcuts.toggleMasking() then
    masking.maskingActive = not masking.maskingActive
  end

  ui.pushID(state.activeTool.name)
  ui.pushFont(ui.Font.Small)
  state.activeTool:ui()
  ui.popFont()
  ui.popID()
end

return M
