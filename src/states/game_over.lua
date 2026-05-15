local GameOverState = {}
GameOverState.__index = GameOverState

function GameOverState.new(ctx, payload)
  local self = setmetatable({ ctx = ctx, summary = payload }, GameOverState)

  local meta = ctx.meta
  local score = math.floor(payload.score or 0)
  meta.runs = (meta.runs or 0) + 1
  if score > (meta.bestScore or 0) then meta.bestScore = score end
  if (payload.wavesCleared or 0) > (meta.bestWaves or 0) then meta.bestWaves = payload.wavesCleared or 0 end
  if (payload.spartans or 0) > (meta.bestSpartans or 0) then meta.bestSpartans = payload.spartans or 0 end
  ctx.save.saveMeta(meta)

  return self
end

function GameOverState:draw()
  local v = self.ctx.view
  local w, h = v.W, v.H
  local f = self.ctx.fonts

  love.graphics.setFont(f.lg)
  love.graphics.setColor(0.95, 0.6, 0.6)
  love.graphics.printf("THE LINE BROKE", 0, h * 0.18, w, "center")

  love.graphics.setFont(f.md)
  love.graphics.setColor(0.95, 0.85, 0.7)
  love.graphics.printf("Score: " .. math.floor(self.summary.score), 0, h * 0.36, w, "center")
  love.graphics.printf("Waves Cleared: " .. tostring(self.summary.wavesCleared), 0, h * 0.45, w, "center")
  love.graphics.printf("Spartans Remaining: " .. tostring(self.summary.spartans), 0, h * 0.52, w, "center")

  love.graphics.setColor(0.9, 0.8, 0.55)
  love.graphics.printf("Best Score: " .. tostring(self.ctx.meta.bestScore or 0), 0, h * 0.60, w, "center")
  love.graphics.printf("Runs: " .. tostring(self.ctx.meta.runs or 0), 0, h * 0.65, w, "center")

  love.graphics.setFont(f.sm)
  love.graphics.setColor(0.8, 0.75, 0.65)
  love.graphics.printf("Press R to Retry or ESC for Menu", 0, h * 0.74, w, "center")
end

function GameOverState:keypressed(key)
  if key == "r" then
    package.loaded["src.states.run"] = nil
    local RunState = require("src.states.run")
    self.ctx.manager:switch(RunState.new(self.ctx, { seed = os.time() }))
  elseif key == "escape" then
    local MenuState = require("src.states.menu")
    self.ctx.manager:switch(MenuState.new(self.ctx))
  end
end

return GameOverState
