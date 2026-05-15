local StateManager = {}
StateManager.__index = StateManager

function StateManager.new()
  return setmetatable({ current = nil }, StateManager)
end

function StateManager:switch(state, payload)
  if self.current and self.current.leave then
    self.current:leave()
  end
  self.current = state
  if self.current and self.current.enter then
    self.current:enter(payload)
  end
end

function StateManager:update(dt)
  if self.current and self.current.update then
    self.current:update(dt)
  end
end

function StateManager:draw()
  if self.current and self.current.draw then
    self.current:draw()
  end
end

function StateManager:keypressed(key)
  if self.current and self.current.keypressed then
    self.current:keypressed(key)
  end
end

function StateManager:keyreleased(key)
  if self.current and self.current.keyreleased then
    self.current:keyreleased(key)
  end
end

function StateManager:mousepressed(x, y, button)
  if self.current and self.current.mousepressed then
    self.current:mousepressed(x, y, button)
  end
end

function StateManager:mousereleased(x, y, button)
  if self.current and self.current.mousereleased then
    self.current:mousereleased(x, y, button)
  end
end

return StateManager
