local Save = {}

local FILE = "meta.lua"

local function defaultMeta()
  return {
    bestScore = 0,
    bestWaves = 0,
    bestSpartans = 0,
    runs = 0,
  }
end

function Save.loadMeta()
  if not love.filesystem.getInfo(FILE) then
    return defaultMeta()
  end

  local chunk = love.filesystem.load(FILE)
  if not chunk then return defaultMeta() end
  local ok, data = pcall(chunk)
  if not ok or type(data) ~= "table" then
    return defaultMeta()
  end

  local meta = defaultMeta()
  for k, v in pairs(data) do meta[k] = v end
  return meta
end

function Save.saveMeta(meta)
  local content = string.format(
    "return { bestScore = %d, bestWaves = %d, bestSpartans = %d, runs = %d }\n",
    math.floor(meta.bestScore or 0),
    math.floor(meta.bestWaves or 0),
    math.floor(meta.bestSpartans or 0),
    math.floor(meta.runs or 0)
  )
  love.filesystem.write(FILE, content)
end

return Save
