local Audio = {}
Audio.__index = Audio

local function tone(freq, duration, volume)
  local rate = 44100
  local samples = math.floor(duration * rate)
  local data = love.sound.newSoundData(samples, rate, 16, 1)
  for i = 0, samples - 1 do
    local t = i / rate
    local env = 1 - (i / samples)
    local s = math.sin(2 * math.pi * freq * t) * env * volume
    data:setSample(i, s)
  end
  return love.audio.newSource(data)
end

function Audio.new()
  local self = setmetatable({}, Audio)
  self.sfx = {
    kill = tone(180, 0.05, 0.35),
    burst = tone(80, 0.18, 0.5),
    boss_strike = tone(60, 0.22, 0.6),
    wave_clear = tone(320, 0.12, 0.4),
    warning = tone(140, 0.08, 0.35),
  }
  return self
end

function Audio:play(name)
  local s = self.sfx[name]
  if not s then return end
  local c = s:clone()
  c:play()
end

return Audio
