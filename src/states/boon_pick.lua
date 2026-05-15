local boonModule = require("src.data.boons")

local BoonPickState = {}
BoonPickState.__index = BoonPickState

function BoonPickState.new(ctx, payload)
  return setmetatable({
    ctx = ctx,
    run = payload.run,
    choices = payload.choices,
  }, BoonPickState)
end

local function rarityLabel(r)
  if r == "common" then return "COMMON" end
  if r == "uncommon" then return "UNCOMMON" end
  if r == "rare" then return "RARE" end
  return "?"
end

local function archLabel(a)
  return string.upper(a or "")
end

function BoonPickState:draw()
  local v = self.ctx.view
  local w, h = v.W, v.H
  local f = self.ctx.fonts

  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", 0, 0, w, h)

  love.graphics.setFont(f.lg)
  love.graphics.setColor(0.95, 0.85, 0.65)
  love.graphics.printf("CHOOSE A BOON", 0, 60, w, "center")

  love.graphics.setFont(f.sm)
  love.graphics.setColor(0.8, 0.72, 0.6)
  love.graphics.printf("Each choice shapes your run.", 0, 110, w, "center")

  local cardW = math.min(360, math.floor((w - 120) / 3))
  local gap = 30
  local totalW = cardW * 3 + gap * 2
  local startX = (w - totalW) / 2
  local cardY = 170

  for i, boon in ipairs(self.choices) do
    local x = startX + (i - 1) * (cardW + gap)
    local rarColor = boonModule.rarityColor(boon.rarity)
    local archColor = boonModule.archColor(boon.archetype)

    -- card background
    love.graphics.setColor(0.10, 0.06, 0.06)
    love.graphics.rectangle("fill", x, cardY, cardW, 320)
    -- rarity border
    love.graphics.setColor(rarColor)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", x, cardY, cardW, 320)
    love.graphics.setLineWidth(1)

    -- archetype strip
    love.graphics.setColor(archColor[1], archColor[2], archColor[3], 0.85)
    love.graphics.rectangle("fill", x, cardY, cardW, 8)

    love.graphics.setFont(f.sm)
    love.graphics.setColor(archColor)
    love.graphics.printf(archLabel(boon.archetype), x + 14, cardY + 20, cardW - 28, "left")
    love.graphics.setColor(rarColor)
    love.graphics.printf(rarityLabel(boon.rarity), x + 14, cardY + 20, cardW - 28, "right")

    love.graphics.setFont(f.md)
    love.graphics.setColor(0.96, 0.88, 0.70)
    love.graphics.printf(boon.name, x + 14, cardY + 60, cardW - 28, "center")

    love.graphics.setFont(f.sm)
    love.graphics.setColor(0.78, 0.72, 0.62)
    love.graphics.printf(boon.desc, x + 14, cardY + 130, cardW - 28, "center")

    -- number hint
    love.graphics.setFont(f.lg)
    love.graphics.setColor(rarColor)
    love.graphics.printf(tostring(i), x, cardY + 240, cardW, "center")

    -- stackable hint
    if boon.stackable then
      love.graphics.setFont(f.sm)
      love.graphics.setColor(0.6, 0.55, 0.45)
      love.graphics.printf("(stackable)", x + 14, cardY + 295, cardW - 28, "center")
    end
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
    self.run.takenBoons = self.run.takenBoons or {}
    self.run.takenBoons[boon.id] = (self.run.takenBoons[boon.id] or 0) + 1
    self.run.boons = self.run.boons or {}
    table.insert(self.run.boons, {
      id = boon.id,
      name = boon.name,
      archetype = boon.archetype,
      rarity = boon.rarity,
    })

    local RunState = require("src.states.run")
    self.ctx.manager:switch(RunState.new(self.ctx, { continueRun = self.run }))
  end
end

return BoonPickState
