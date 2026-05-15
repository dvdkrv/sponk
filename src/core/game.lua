local StateManager = require("src.core.state_manager")
local Save = require("src.core.save")
local Audio = require("src.core.audio")

local MenuState = require("src.states.menu")

local Game = {}

function Game.load()
  love.graphics.setBackgroundColor(0.04, 0.02, 0.02)
  love.graphics.setDefaultFilter("nearest", "nearest")

  local manager = StateManager.new()
  Game.manager = manager
  Game.ctx = {
    manager = manager,
    meta = Save.loadMeta(),
    save = Save,
    audio = Audio.new(),
    fonts = {
      sm = love.graphics.newFont(14),
      md = love.graphics.newFont(20),
      lg = love.graphics.newFont(34),
    },
  }

  manager:switch(MenuState.new(Game.ctx))
end

function Game.update(dt)
  Game.manager:update(dt)
end

function Game.draw()
  Game.manager:draw()
end

function Game.keypressed(key)
  Game.manager:keypressed(key)
end

function Game.keyreleased(key)
  if Game.manager.keyreleased then
    Game.manager:keyreleased(key)
  end
end

function Game.mousepressed(x, y, button)
  Game.manager:mousepressed(x, y, button)
end

function Game.mousereleased(x, y, button)
  Game.manager:mousereleased(x, y, button)
end

return Game
