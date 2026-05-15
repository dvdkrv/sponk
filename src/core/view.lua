local View = {}

View.W = 1280
View.H = 720

function View.scale()
  local w, h = love.graphics.getDimensions()
  return math.min(w / View.W, h / View.H)
end

function View.offsets()
  local s = View.scale()
  local w, h = love.graphics.getDimensions()
  return (w - View.W * s) / 2, (h - View.H * s) / 2
end

function View.apply()
  local s = View.scale()
  local ox, oy = View.offsets()
  love.graphics.push()
  love.graphics.translate(ox, oy)
  love.graphics.scale(s, s)

  -- letterbox bars
  love.graphics.setColor(0, 0, 0)
end

function View.unapply()
  love.graphics.pop()
end

function View.toVirtual(x, y)
  local s = View.scale()
  local ox, oy = View.offsets()
  return (x - ox) / s, (y - oy) / s
end

return View
