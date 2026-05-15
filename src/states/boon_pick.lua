local BoonPickState = {}
BoonPickState.__index = BoonPickState

function BoonPickState.new(ctx, payload)
  return setmetatable({
    ctx = ctx,
    run = payload.run,
    choices = payload.choices,
  }, BoonPickState)
end

function BoonPickState:draw()
  local v = self.ctx.view
  local w, h = v.W, v.H
  local f = self.ctx.fonts
  love.graphics.setFont(f.md)
  love.graphics.setColor(0.95, 0.85, 0.65)
  love.graphics.printf("CHOOSE A BOON", 0, 80, w, "center")

  for i, boon in ipairs(self.choices) do
    local y = 180 + (i - 1) * 140
    love.graphics.setColor(0.14, 0.08, 0.08)
    love.graphics.rectangle("fill", 160, y, w - 320, 110)
    love.graphics.setColor(0.55, 0.35, 0.25)
    love.graphics.rectangle("line", 160, y, w - 320, 110)

    love.graphics.setColor(0.95, 0.85, 0.65)
    love.graphics.printf(i .. ". " .. boon.name, 180, y + 18, w - 360, "left")
    love.graphics.setFont(f.sm)
    love.graphics.setColor(0.8, 0.72, 0.65)
    love.graphics.printf(boon.desc, 180, y + 56, w - 360, "left")
    love.graphics.setFont(f.md)
  end

  love.graphics.setFont(f.sm)
  love.graphics.setColor(0.95, 0.9, 0.7)
  love.graphics.printf("Press 1, 2, or 3", 0, h - 70, w, "center")
end

function BoonPickState:keypressed(key)
  local index = tonumber(key)
  if index and self.choices[index] then
    local boon = self.choices[index]
    boon.apply(self.run)
    local RunState = require("src.states.run")
    self.ctx.manager:switch(RunState.new(self.ctx, { continueRun = self.run }))
  end
end

return BoonPickState
