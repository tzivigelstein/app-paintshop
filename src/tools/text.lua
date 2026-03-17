local base      = require('src/tools/base')
local palette   = require('src/palette')
local shortcuts = require('src/shortcuts')
local assets    = require('src/assets')
local state     = require('src/state')

return {
  name  = 'Text (T)',
  key   = shortcuts.toolText,
  icon  = assets.icons.Text,
  brush = base.brushParams('text', 0.2, 1),

  ui = function (s)
    if assets.fonts == nil then assets.rescanFonts() end

    local selectedFont = table.findFirst(assets.fonts, function (item, _, sf) return item.source == sf end, state.stored.selectedFont)
    if selectedFont == nil then
      selectedFont = assets.fonts[1]
      state.stored.selectedFont = selectedFont.source
    end

    ui.header('Color:')
    require('src/ui/components').ColorBlock()
    ui.offsetCursorY(20)

    ui.beginGroup()
    ui.header('Text:')
    s._labelText = ui.inputText('Text', s._labelText, ui.InputTextFlags.Placeholder)
    if ui.itemEdited() then s._labelDirty = true end

    ui.combo('##fonts', 'Font: '..tostring(selectedFont.name), ui.ComboFlags.None, function ()
      for i = 1, #assets.fonts do
        if ui.selectable(assets.fonts[i].name, assets.fonts[i] == selectedFont) then
          selectedFont = assets.fonts[i]
          state.stored.selectedFont, s._labelDirty = selectedFont.source, true
        end
        if ui.itemHovered() then
          ui.tooltip(function ()
            if s._previewCanvas ~= nil then s._previewCanvas:dispose() end
            local font = assets.fonts[i].source
            if state.stored.fontBold   then font = font..';Weight=Bold' end
            if state.stored.fontItalic then font = font..';Style=Italic' end
            ui.pushDWriteFont(font)
            local sz = ui.measureDWriteText(s._labelText, 24)
            sz.x, sz.y = math.max(sz.x, 24), sz.y + 8
            s._previewCanvas = ui.ExtraCanvas(sz):clear(rgbm.colors.transparent):update(function ()
              ui.dwriteTextAligned(s._labelText, 24, ui.Alignment.Center, ui.Alignment.Center, ui.availableSpace(), false, rgbm.colors.white)
            end)
            ui.popDWriteFont()
            ui.image(s._previewCanvas, sz)
          end)
        end
      end
    end)

    ui.itemPopup(function ()
      if ui.selectable('Open in Explorer') then os.openInExplorer(state.fontsDir) end
      if ui.selectable('Refresh') then assets.rescanFonts() end
    end)

    if ui.checkbox('Bold',   state.stored.fontBold)   then state.stored.fontBold,   s._labelDirty = not state.stored.fontBold,   true end
    if ui.checkbox('Italic', state.stored.fontItalic) then state.stored.fontItalic, s._labelDirty = not state.stored.fontItalic, true end
    ui.endGroup()

    if ui.itemHovered() and not s._labelDirty then
      ui.tooltip(function ()
        if type(s.brush.brushTex) ~= 'string' then
          ui.image(s.brush.brushTex, ui.imageSize(s.brush.brushTex):scale(0.5))
        end
      end)
    end

    ui.alignTextToFramePadding()
    ui.text('Align text:')
    ui.sameLine()
    ui.setNextItemWidth(ui.availableSpaceX())
    state.stored.alignSticker = ui.combo('##alignSticker', state.stored.alignSticker, ui.ComboFlags.None, {
      'No', 'Align to surface', 'Fully align',
    })

    base.BrushBaseBlock(s.brush, 4, true)

    if s._labelDirty then
      if s.brush.brushTex and type(s.brush.brushTex) ~= 'string' then
        s.brush.brushTex:dispose()
      end
      local font = selectedFont.source
      if state.stored.fontBold   then font = font..';Weight=Bold' end
      if state.stored.fontItalic then font = font..';Style=Italic' end
      ui.pushDWriteFont(font)
      local sz = ui.measureDWriteText(s._labelText, 48)
      sz.x, sz.y = math.max(sz.x, 48), sz.y + 16
      s.brush.brushTex = ui.ExtraCanvas(sz):clear(rgbm.colors.transparent):update(function ()
        ui.dwriteTextAligned(s._labelText, 48, ui.Alignment.Center, ui.Alignment.Center, ui.availableSpace(), false, rgbm.colors.white)
      end)
      ui.popDWriteFont()
      s._labelDirty = false
    end
  end,

  brushColor = function (s)
    return rgbm.new(state.stored.color.rgb, s.brush.brushAlpha)
  end,

  brushSize = function (s)
    local size = ui.imageSize(s.brush.brushTex)
    return vec2(s.brush.brushSize, s.brush.brushSize * size.y / size.x)
  end,

  stickerMode       = true,
  stickerContinious = false,
  blendMode         = render.BlendMode.BlendPremultiplied,

  _labelText  = ac.getDriverName(0),
  _labelDirty = true,
}
