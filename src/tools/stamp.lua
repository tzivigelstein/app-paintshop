local base      = require('src/tools/base')
local palette   = require('src/palette')
local shortcuts = require('src/shortcuts')
local assets    = require('src/assets')
local state     = require('src/state')

return {
  name  = 'Stamp (S)',
  key   = shortcuts.toolStamp,
  icon  = assets.icons.Stamp,
  brush = base.brushParams('stamp', 0.2, 1),

  ui = function (s)
    ui.header('Color:')
    require('src/ui/components').ColorBlock()
    ui.offsetCursorY(20)

    ui.header('Stamp:')
    ui.combo('##set', string.format('Set: %s', assets.selectedStickerSet.name), ui.ComboFlags.None, function ()
      for i = 1, #assets.stickers do
        if ui.selectable(assets.stickers[i].name, assets.stickers[i] == assets.selectedStickerSet) then
          assets.selectedStickerSet = assets.stickers[i]
          state.stored.selectedStickerSet = i
        end
      end
      if ui.selectable('New category\xe2\x80\xa6') then
        ui.modalPrompt('Create new category', 'Category name:', nil, function (value)
          if #value > 0 and io.createDir(state.decalsDir..'/'..value) then
            ui.toast(ui.Icons.Confirm, 'New category created: '..tostring(value))
            assets.rescanStickers()
            assets.selectedStickerSet = table.findFirst(assets.stickers, function (item) return item.name == value end)
          else
            ui.toast(ui.Icons.Warning, 'Couldn\xe2\x80\x99t create a new category: '..tostring(value))
          end
        end)
      end
    end)

    local items = assets.selectedStickerSet.items
    if s.brush.brushTex == '' then s.brush.brushTex = items[1][2] end

    ui.childWindow('stickersList', vec2(210, 210), false, ui.WindowFlags.AlwaysVerticalScrollbar, function ()
      ui.pushStyleColor(ui.StyleColor.Button, rgbm.colors.transparent)
      local itemSize = vec2(100, 60)
      for i = 1, #items do
        if ui.areaVisible(itemSize) then
          local size = ui.imageSize(items[i][2])
          if ui.button('##si'..i, vec2(100, 60), s.brush.brushTex == items[i][2] and ui.ButtonFlags.Active or ui.ButtonFlags.None) then
            s.brush.brushTex = items[i][2]
            state.selectedBrushOutlineDirty = true
          end
          local iconSize = vec2(90, 90 * size.y / size.x)
          if iconSize.y > 54 then iconSize:scale(54 / iconSize.y) end
          ui.addIcon(items[i][2], iconSize, 0.5, nil, 0)
          if ui.itemHovered() then ui.setTooltip('Stamp: '..items[i][1]) end
        else
          ui.dummy(itemSize)
        end
        if i % 2 == 1 then ui.sameLine(0, 0) end
      end
      ui.popStyleColor()
      ui.newLine()
    end)

    local _, i = table.findFirst(items, function (item, _, tex) return item[2] == tex end, s.brush.brushTex)
    i = i or 0

    if shortcuts.arrowRight() then s.brush.brushTex = items[i % #items + 1][2];           state.selectedBrushOutlineDirty = true end
    if shortcuts.arrowDown()  then s.brush.brushTex = items[(i + 1) % #items + 1][2];     state.selectedBrushOutlineDirty = true end
    if shortcuts.arrowLeft()  then s.brush.brushTex = items[(i - 2 + #items) % #items + 1][2]; state.selectedBrushOutlineDirty = true end
    if shortcuts.arrowUp()    then s.brush.brushTex = items[(i - 3 + #items) % #items + 1][2]; state.selectedBrushOutlineDirty = true end

    if ui.itemHovered() then ui.setTooltip('Use arrow keys to quickly switch between items') end

    ui.itemPopup(function ()
      if ui.selectable('Add new decal\xe2\x80\xa6') then
        os.openFileDialog({
          title             = 'Add new decal',
          defaultFolder     = ac.getFolder(ac.FolderID.Root),
          fileTypes         = { { name = 'Images', mask = '*.png' } },
          addAllFilesFileType = true,
          flags             = bit.bor(os.DialogFlags.PathMustExist, os.DialogFlags.FileMustExist),
        }, function (err, filename)
          if filename then
            local fileName = filename:gsub('.+[/\\\\]', '')
            if io.copyFile(filename, state.decalsDir..'/'..assets.selectedStickerSet.name..'/'..fileName, true) then
              assets.rescanStickers()
              assets.selectedStickerSet = table.findFirst(assets.stickers, function (item) return item.name == assets.selectedStickerSet.name end)
              s.brush.brushTex = state.decalsDir..'/'..assets.selectedStickerSet.name..'/'..fileName
              ui.toast(ui.Icons.Confirm, 'New decal added: '..fileName:sub(1, #fileName - 4))
              return
            end
          end
          if err or filename then
            ui.toast(ui.Icons.Warning, 'Couldn\xe2\x80\x99t add a new decal: '..(err or 'unknown error'))
          end
        end)
      end
      if ui.selectable('Open in Explorer') then os.openInExplorer(state.decalsDir) end
      if ui.selectable('Refresh') then assets.rescanStickers() end
    end)

    ui.alignTextToFramePadding()
    ui.text('Align sticker:')
    ui.sameLine()
    ui.setNextItemWidth(ui.availableSpaceX())
    state.stored.alignSticker = ui.combo('##alignSticker', state.stored.alignSticker, ui.ComboFlags.None, {
      'No', 'Align to surface', 'Fully align',
    })

    base.BrushBaseBlock(s.brush, 4, true)
  end,

  brushColor = function (s)
    return rgbm.new(state.stored.color.rgb, s.brush.brushAlpha)
  end,

  brushSize = function (s)
    local size = ui.imageSize(s.brush.brushTex)
    return vec2(s.brush.brushSize, s.brush.brushSize * size.y / size.x)
  end,

  stickerMode      = true,
  stickerContinious = false,
}
