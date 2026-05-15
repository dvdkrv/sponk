local MenuState = {}
MenuState.__index = MenuState

function MenuState.new(ctx)
  return setmetatable({ ctx = ctx }, MenuState)
end

function MenuState:draw()
  local w, h = love.graphics.getDimensions()
  local f = self.ctx.fonts
  love.graphics.setFont(f.lg)
  love.graphics.setColor(0.92, 0.85, 0.72)
  love.graphics.printf("PHALANX / 300", 0, h * 0.22, w, "center")

  love.graphics.setFont(f.md)
  love.graphics.setColor(0.85, 0.3, 0.3)
  love.graphics.printf("300 SPARTANS. BLOOD. GLORY.", 0, h * 0.36, w, "center")

  love.graphics.setFont(f.sm)
  love.graphics.setColor(0.8, 0.75, 0.65)
  love.graphics.printf("HOLD = survive longer", 0, h * 0.50, w, "center")
  love.graphics.printf("CHARGE (Space / Left Mouse) = kill faster, lose men faster", 0, h * 0.55, w, "center")
  love.graphics.printf("P = Pause", 0, h * 0.60, w, "center")

  love.graphics.setColor(0.9, 0.8, 0.55)
  love.graphics.printf("Best Score: " .. tostring(self.ctx.meta.bestScore or 0), 0, h * 0.68, w, "center")

  love.graphics.setFont(f.md)
  love.graphics.setColor(0.95, 0.9, 0.6)
  love.graphics.printf("Press ENTER to Start", 0, h * 0.76, w, "center")
end

function MenuState:keypressed(key)
  if key == "return" or key == "kpenter" then
    local RunState = require("src.states.run")
    self.ctx.manager:switch(RunState.new(self.ctx, { seed = os.time() }))
  end
end

return MenuState
