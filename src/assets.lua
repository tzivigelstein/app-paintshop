local state = require('src/state')

local M = {}

M.icons = ui.atlasIcons('res/icons.png', 4, 4, {
  Brush           = {1, 1},
  Eraser          = {1, 2},
  Undo            = {1, 3},
  Redo            = {1, 4},
  EyeDropper      = {2, 1},
  Camera          = {2, 2},
  Save            = {2, 3},
  Open            = {2, 4},
  Stamp           = {3, 1},
  Masking         = {3, 2},
  Stencil         = {3, 3},
  Export          = {3, 4},
  Text            = {4, 1},
  MirroringStamp  = {4, 2},
  BlurTool        = {4, 3},
  MirroringHelper = {4, 4},
})

M.brushes          = nil
M.stickers         = nil
M.selectedStickerSet = nil
M.fonts            = nil

function M.rescanBrushes()
  M.brushes = table.map(io.scanDir(state.brushesDir, '*.png'), function (x)
    return { string.sub(x, 1, #x - 4), state.brushesDir..'/'..x }
  end)
end

function M.rescanStickers()
  M.stickers = table.map(io.scanDir(state.decalsDir, '*'), function (x)
    return {
      name  = x,
      items = table.map(io.scanDir(state.decalsDir..'/'..x, '*.png'), function (y)
        return { string.sub(y, 1, #y - 4), state.decalsDir..'/'..x..'/'..y }
      end),
    }
  end)
  M.selectedStickerSet = M.stickers[state.stored.selectedStickerSet]
end

function M.rescanFonts()
  M.fonts = {
    { name = 'Arial',          source = 'Arial:@System' },
    { name = 'Bahnschrift',    source = 'Bahnschrift:@System' },
    { name = 'Calibri',        source = 'Calibri:@System' },
    { name = 'Comic Sans MS',  source = 'Comic Sans MS:@System' },
    { name = 'Consolas',       source = 'Consolas' },
    { name = 'Courier New',    source = 'Courier New:@System' },
    { name = 'Impact',         source = 'Impact:@System' },
    { name = 'Orbitron',       source = 'Orbitron' },
    { name = 'Segoe UI',       source = 'Segoe UI' },
    { name = 'Times New Roman', source = 'Times New Roman:@System' },
    { name = 'VCR OSD Mono',   source = 'VCR OSD Mono' },
    { name = 'Webdings',       source = 'Webdings:@System' },
  }
  for _, v in ipairs(io.scanDir(state.fontsDir, '*.ttf')) do
    table.insert(M.fonts, {
      name   = v:sub(1, #v - 4),
      source = v:sub(1, #v - 4)..':'..state.fontsDir,
    })
  end
  table.sort(M.fonts, function (a, b) return a.name < b.name end)
end

return M
