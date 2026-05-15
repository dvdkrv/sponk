local RNG = {}
RNG.__index = RNG

function RNG.new(seed)
  local self = setmetatable({}, RNG)
  self.seed = seed or os.time()
  self.state = self.seed
  return self
end

function RNG:next()
  -- LCG (deterministic)
  self.state = (1103515245 * self.state + 12345) % 2147483648
  return self.state / 2147483648
end

function RNG:range(min, max)
  return math.floor(self:next() * (max - min + 1)) + min
end

function RNG:pick(list)
  if #list == 0 then return nil end
  return list[self:range(1, #list)]
end

return RNG
