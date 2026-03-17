-- Pure AO compositing shader. No dependencies on mutable state.
-- updateAOCanvas and updateBrushOutline live in painting.lua because they
-- call projectBrushTexture, keeping the dependency graph acyclic.

local M = {}

function M.drawWithAO(baseCanvas, aoTexture)
  ui.renderShader({
    p1        = vec2(),
    p2        = ui.windowSize(),
    blendMode = render.BlendMode.Opaque,
    textures  = {
      txBase = baseCanvas,
      txAO   = aoTexture,
    },
    shader = [[float4 main(PS_IN pin) {
      float4 diffuseColor = txAO.SampleLevel(samLinear, pin.Tex, 0);
      float4 canvasColor  = txBase.SampleLevel(samLinear, pin.Tex, 0);
      canvasColor.rgb *= max(diffuseColor.r, max(diffuseColor.g, diffuseColor.b));
      canvasColor.a = 1;
      return canvasColor;
    }]],
  })
end

return M
