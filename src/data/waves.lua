-- Wave definitions are generated as dense, continuous streams.
-- Each wave specifies arrival rates (per second) per enemy type.

local function build(duration, rates)
  local spawns = {}
  for _, entry in ipairs(rates) do
    local tname, rate = entry[1], entry[2]
    local interval = 1 / rate
    local t = 0.3 + math.random() * 0.6
    while t < duration do
      table.insert(spawns, { t = t, type = tname })
      t = t + interval * (0.6 + math.random() * 0.8)
    end
  end
  table.sort(spawns, function(a, b) return a.t < b.t end)
  return { duration = duration, spawns = spawns }
end

return {
  build(20, {
    { "soldier", 1.8 },
    { "archer", 0.9 },
    { "brute",  0.30 },
  }),
  build(22, {
    { "soldier", 2.4 },
    { "archer", 1.2 },
    { "brute",  0.45 },
  }),
  build(24, {
    { "soldier", 3.0 },
    { "archer", 1.6 },
    { "brute",  0.65 },
  }),
}
