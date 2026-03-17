local M = {}

-- AC context (initialized once at load time)
M.sim      = ac.getSim()
M.uiState  = ac.getUI()
M.car      = ac.getCar(0)
M.carDir   = ac.getFolder(ac.FolderID.ContentCars)..'/'..ac.getCarID(0)
M.skinDir  = M.carDir..'/skins/'..ac.getCarSkinID(0)
M.carNode  = ac.findNodes('carRoot:0')
M.carMeshes = M.carNode:findMeshes('{ ! material:DAMAGE_GLASS & lod:A }')

-- Directory paths
M.brushesDir  = __dirname..'/brushes'
M.decalsDir   = __dirname..'/decals'
M.fontsDir    = __dirname..'/fonts'
M.autosaveDir = ac.getFolder(ac.FolderID.Cfg)..'/apps/paintshop/autosave'

-- Rendering constants
M.taaFix = { On = 1, Off = 0 }

-- Persistent settings (ac.storage keeps values across sessions)
M.stored = ac.storage{
  color              = rgbm(0, 0.2, 1, 0.5),
  bgColor            = rgbm(1, 1, 1, 1),
  orbitCamera        = true,
  projectOtherSide   = false,
  eyeDropperRange    = 1,
  selectedStickerSet = 2,
  alignSticker       = 3,
  activeToolIndex    = 1,
  selectedFont       = '',
  fontBold           = false,
  fontItalic         = false,
  hasPen             = false,
}

-- App window visibility
M.appVisible = false

-- Active editing session (nil = no session open)
M.selectedMeshes = nil  ---@type ac.SceneReference
M.carTexture     = nil
M.aoTexture      = nil
M.saveFilename   = nil
M.changesMade    = 0

-- Canvases
M.editingCanvas      = nil  ---@type ui.ExtraCanvas
M.aoCanvas           = nil  ---@type ui.ExtraCanvas
M.maskingCanvas      = nil  ---@type ui.ExtraCanvas
M.accessibleData     = nil  ---@type ui.ExtraCanvasData
M.editingCanvasPhase = 0

-- Painting runtime state
M.drawing               = false
M.ignoreMousePress      = true
M.brushDistance         = 1
M.lastRay               = nil  ---@type ray
M.smoothRayDir          = nil
M.selectedBrushOutline      = nil  ---@type ui.ExtraCanvas
M.selectedBrushOutlineDirty = true

-- Camera
M.camera      = nil  ---@type ac.GrabbedCamera
M.cameraAngle = vec2(-2.6, 0.1)

-- Active tool management
M.activeTool        = nil
M.previousToolIndex = 1
M.toolSwitched      = 0

-- Debug texture (nil in production)
M.debugTex = nil

return M
