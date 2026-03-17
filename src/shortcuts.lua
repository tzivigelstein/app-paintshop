local M = {
  undo                    = ui.shortcut({ key = ui.KeyIndex.Z, ctrl = true }, ui.KeyIndex.XButton1),
  redo                    = ui.shortcut({ key = ui.KeyIndex.Y, ctrl = true }, ui.KeyIndex.XButton2),
  save                    = ui.shortcut{ key = ui.KeyIndex.S, ctrl = true },
  export                  = ui.shortcut{ key = ui.KeyIndex.S, ctrl = true, shift = true, alt = true },
  load                    = ui.shortcut{ key = ui.KeyIndex.O, ctrl = true },
  swapColors              = ui.shortcut(ui.KeyIndex.X),
  flipSticker             = ui.shortcut(ui.KeyIndex.Z),
  toggleSymmetry          = ui.shortcut(ui.KeyIndex.Y),
  toggleDrawThrough       = ui.shortcut(ui.KeyIndex.R),
  toolBrush               = ui.shortcut(ui.KeyIndex.B),
  toolEraser              = ui.shortcut(ui.KeyIndex.E),
  toolStamp               = ui.shortcut(ui.KeyIndex.S),
  toolMirroringStamp      = ui.shortcut(ui.KeyIndex.K),
  toolBlurTool            = ui.shortcut({ key = ui.KeyIndex.B, alt = true }),
  toolEyeDropper          = ui.shortcut(ui.KeyIndex.I),
  toolMasking             = ui.shortcut(ui.KeyIndex.M),
  toolText                = ui.shortcut(ui.KeyIndex.T),
  toggleMasking           = ui.shortcut({ key = ui.KeyIndex.M, ctrl = true }),
  toggleOrbitCamera       = ui.shortcut({ key = ui.KeyIndex.Space, ctrl = true }),
  toggleProjectOtherSide  = ui.shortcut({ key = ui.KeyIndex.E, ctrl = true }),
  arrowLeft               = ui.shortcut(ui.KeyIndex.Left),
  arrowRight              = ui.shortcut(ui.KeyIndex.Right),
  arrowUp                 = ui.shortcut(ui.KeyIndex.Up),
  arrowDown               = ui.shortcut(ui.KeyIndex.Down),
  opacity = table.range(9, 0, function (index)
    return ui.shortcut(ui.KeyIndex.D0 + index), index
  end),
}

return M
