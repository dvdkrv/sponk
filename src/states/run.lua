local RNG = require("src.core.rng")
local Ops = require("src.core.run_ops")
local tuning = require("src.data.tuning")
local enemyData = require("src.data.enemies")
local waves = require("src.data.waves")
local boonModule = require("src.data.boons")
local boons = boonModule.list

local BoonPickState = require("src.states.boon_pick")
local GameOverState = require("src.states.game_over")

local RunState = {}
RunState.__index = RunState

function RunState.new(ctx, payload)
  local self = setmetatable({}, RunState)
  self.ctx = ctx

  if payload.continueRun then
    self.run = payload.continueRun
    self.run.mode = "hold"
    self.run.chargeHeld = false
    self.run.waveStart = self.run.time
  else
    local seed = payload.seed or os.time()
    self.run = {
      seed = seed,
      rng = RNG.new(seed),
      spartans = tuning.spartan.startCount,
      mode = "hold",
      chargeHeld = false,
      rage = 0,
      combo = 0,
      comboPeak = 0,
      comboTimer = 0,
      score = 0,
      enemiesKilled = 0,
      time = 0,
      waveIndex = 1,
      wavesCleared = 0,
      inBoss = false,
      bossHP = enemyData.godking.hp,
      mod = Ops.defaultMod(),
      boons = {},
      takenBoons = {},
      enemies = {},
      spawnCursor = 1,
      waveClock = 0,
      waveStart = 0,
      pendingDeaths = 0,
      hitFlash = 0,
      burst = false,
      burstDrain = 0,
      bossStrikeClock = 0,
      particles = {},
      shakeTime = 0,
      shakePower = 0,
      hitstop = 0,
      paused = false,
      warningText = "",
      warningTime = 0,
      warning200 = false,
      warning100 = false,
      warning50 = false,
      frontAdvance = 0,
      rows = nil,
      rowDeath = nil,
    }
    self.run.rows = {}
    self.run.rowDeath = {}
    for r = 1, 12 do
      self.run.rows[r] = 25
      self.run.rowDeath[r] = 0
    end
    self.run.spartans = Ops.spartansAlive(self.run)
  end

  self:initWaveIfNeeded()
  return self
end

function RunState:spartansAlive()
  return Ops.spartansAlive(self.run)
end

function RunState:initWaveIfNeeded()
  local run = self.run
  if run.inBoss then return end

  if run.waveIndex > #waves then
    run.inBoss = true
    run.enemies = {}
    run.waveClock = 0
    run.bossStrikeClock = 0
    return
  end

  run.enemies = run.enemies or {}
  run.spawnCursor = 1
  run.waveClock = 0
end

function RunState:currentWave()
  return waves[self.run.waveIndex]
end

function RunState:gaussianY()
  local run = self.run
  local bf = tuning.battlefield
  -- Box-Muller via the run's deterministic RNG
  local u1 = math.max(1e-6, run.rng:next())
  local u2 = run.rng:next()
  local z = math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2)
  local center = (bf.topY + bf.bottomY) / 2
  local stdev = (bf.bottomY - bf.topY) / 6
  local y = center + z * stdev
  if y < bf.topY + 10 then y = bf.topY + 10 end
  if y > bf.bottomY - 10 then y = bf.bottomY - 10 end
  return y
end

function RunState:spawnEnemy(kind)
  local run = self.run
  local data = enemyData[kind]
  local scale = 1 + (run.waveIndex - 1) * 0.12
  table.insert(run.enemies, {
    type = kind,
    hp = data.hp * scale,
    speed = data.speed * (1 + (run.waveIndex - 1) * 0.04),
    damage = data.damage * scale,
    score = data.score,
    y = self:gaussianY(),
    x = tuning.battlefield.rightX,
    color = data.color,
  })
end

function RunState:pickBoons(n)
  local run = self.run
  -- archetype affinity: more weight to archetypes already picked
  local archCount = {}
  for _, b in ipairs(run.boons or {}) do
    archCount[b.archetype] = (archCount[b.archetype] or 0) + 1
  end

  local pool = {}
  for _, b in ipairs(boons) do
    local taken = run.takenBoons[b.id]
    if (not taken) or b.stackable then
      local weight = (b.rarity == "common" and 6) or (b.rarity == "uncommon" and 3) or 1
      weight = weight * (1 + (archCount[b.archetype] or 0) * 0.4)
      -- penalty for repeats so stackables don't always dominate
      if taken then weight = weight * 0.5 end
      for _ = 1, math.max(1, math.floor(weight)) do
        table.insert(pool, b)
      end
    end
  end

  if #pool == 0 then return {} end
  local picked, used = {}, {}
  local attempts = 0
  while #picked < n and attempts < 400 do
    attempts = attempts + 1
    local b = pool[run.rng:range(1, #pool)]
    if not used[b.id] then
      used[b.id] = true
      table.insert(picked, b)
    end
  end
  return picked
end

function RunState:updateWaveSpawns(dt)
  local run = self.run
  local wave = self:currentWave()
  if not wave then return end

  run.waveClock = run.waveClock + dt
  while run.spawnCursor <= #wave.spawns do
    local spawn = wave.spawns[run.spawnCursor]
    if spawn.t <= run.waveClock then
      self:spawnEnemy(spawn.type)
      run.spawnCursor = run.spawnCursor + 1
    else
      break
    end
  end
end

function RunState:emitSfx(event)
  if self.ctx.audio then
    self.ctx.audio:play(event)
  end
end

function RunState:onEnemyKilled(e)
  local run = self.run
  run.enemiesKilled = run.enemiesKilled + 1
  run.score = run.score + tuning.scoring.kill * e.score
  run.combo = run.combo + 1
  run.comboPeak = math.max(run.comboPeak, run.combo)
  run.comboTimer = 1.1
  local rageGain = tuning.rage.gainPerKill * run.mod.rageGainMul
  run.rage = math.min(tuning.rage.max, run.rage + rageGain)

  self:spawnBlood(e.x, e.y, 6 + e.score * 2)
  self:addShake(0.05, 2 + e.score)
  self:addHitstop(0.02)
  self:emitSfx("kill")
end

-- Layout constants for the phalanx (must match draw code)
local PHALANX_COLS = 25
local PHALANX_ROWS = 12
local PHALANX_SPACING_X = 14
local PHALANX_SPACING_Y = 18
local PHALANX_START_OFFSET_X = 30
local PHALANX_BASE_PAD = 6

function RunState:phalanxLayout()
  local bf = tuning.battlefield
  local startX = bf.leftX + PHALANX_START_OFFSET_X
  local fieldH = (PHALANX_ROWS - 1) * PHALANX_SPACING_Y
  local startY = bf.topY + ((bf.bottomY - bf.topY) - fieldH) / 2
  local fieldW = (PHALANX_COLS - 1) * PHALANX_SPACING_X
  return startX, startY, fieldW, fieldH
end

function RunState:staticFrontX()
  local startX, _, fieldW = self:phalanxLayout()
  return startX + fieldW + PHALANX_BASE_PAD
end

function RunState:frontMetrics()
  local run = self.run
  local frontX = self:staticFrontX() + (run.frontAdvance or 0)
  local engageRange = (run.mode == "charge") and 55 or 35
  return frontX, engageRange
end

function RunState:rowForY(y)
  local _, startY = self:phalanxLayout()
  local r = math.floor((y - startY + PHALANX_SPACING_Y / 2) / PHALANX_SPACING_Y) + 1
  if r < 1 then r = 1 end
  if r > PHALANX_ROWS then r = PHALANX_ROWS end
  return r
end

function RunState:corridorBounds(x)
  local bf = tuning.battlefield
  local _, startY = self:phalanxLayout()
  local nearTop = startY - 14
  local nearBot = startY + (PHALANX_ROWS - 1) * PHALANX_SPACING_Y + 14
  local farTop = bf.topY - 40
  local farBot = bf.bottomY + 40

  -- Strait geometry is fixed: pinch is anchored at the static front,
  -- regardless of charge advance (the cliffs don't move).
  local pinchX = self:staticFrontX()
  local farX = bf.rightX + 40

  if x <= pinchX then return nearTop, nearBot end
  if x >= farX then return farTop, farBot end

  local t = (x - pinchX) / (farX - pinchX)
  t = t * t * (3 - 2 * t)
  local top = nearTop + (farTop - nearTop) * t
  local bot = nearBot + (farBot - nearBot) * t
  return top, bot
end

function RunState:updateEnemies(dt)
  local run = self.run
  local frontX = self:frontMetrics()
  local bf = tuning.battlefield

  for i = #run.enemies, 1, -1 do
    local e = run.enemies[i]

    -- bleed tick
    if e.bleedTimer and e.bleedTimer > 0 then
      e.hp = e.hp - (e.bleedDps or 0) * dt
      e.bleedTimer = e.bleedTimer - dt
    end

    -- funnel: clamp y to the corridor at the enemy's current x
    local topB, botB = self:corridorBounds(e.x)
    if e.y < topB then e.y = topB end
    if e.y > botB then e.y = botB end

    local row = self:rowForY(e.y)
    local rowAlive = run.rows[row] > 0

    if rowAlive then
      -- normal advance, stop at the wall, deal contact damage
      if e.x > frontX then
        e.x = e.x - e.speed * dt
        if e.x < frontX then e.x = frontX end
      end
      if e.x <= frontX then
        e.x = frontX
        local mul = (run.mode == "charge") and run.mod.chargeLossMul or run.mod.holdLossMul
        local hpPer = tuning.spartan.spartanHp * run.mod.spartanHpMul
        run.rowDeath[row] = run.rowDeath[row] + e.damage * mul * dt
        while run.rowDeath[row] >= hpPer and run.rows[row] > 0 do
          run.rowDeath[row] = run.rowDeath[row] - hpPer
          run.rows[row] = run.rows[row] - 1
          run.hitFlash = math.max(run.hitFlash, 0.18)
          self:addShake(0.06, 3)
          local sx, sy = self:phalanxLayout()
          self:spawnBlood(sx + (PHALANX_COLS - 1) * PHALANX_SPACING_X, sy + (row - 1) * PHALANX_SPACING_Y, 8)
        end
      end
    else
      -- row collapsed: the persian streams through the breach
      e.x = e.x - e.speed * dt
    end

    if e.hp <= 0 then
      self:onEnemyKilled(e)
      table.remove(run.enemies, i)
    elseif e.x < bf.leftX - 40 then
      table.remove(run.enemies, i)
    end
  end

  run.spartans = self:spartansAlive()
end

function RunState:applySpartanDamage(dt)
  local run = self.run
  local mod = run.mod
  local baseDps = (run.mode == "charge") and tuning.spartan.chargeDps or tuning.spartan.holdDps
  local modeMul = (run.mode == "charge") and mod.chargeDpsMul or mod.holdDpsMul
  baseDps = baseDps * modeMul * mod.allDpsMul

  -- combo scaling
  if mod.comboDamageBonus > 0 then
    baseDps = baseDps * (1 + run.combo * mod.comboDamageBonus)
  end

  -- last stand
  if mod.lastStandThreshold > 0 and run.spartans <= mod.lastStandThreshold then
    baseDps = baseDps * mod.lastStandMul
  end

  -- burst
  if run.burst then
    local burstMul = tuning.rage.burstMultiplier + mod.burstMulBonus
    baseDps = baseDps * burstMul
    run.rage = math.max(0, run.rage - tuning.rage.chargeDrain * mod.burstDrainMul * dt)
    if run.rage <= 0 then run.burst = false end
  end

  local frontX, engageRange = self:frontMetrics()
  local engageMax = frontX + engageRange

  local engaged = {}
  for _, e in ipairs(run.enemies) do
    if e.x <= engageMax then
      table.insert(engaged, e)
    end
  end

  if #engaged > 0 then
    table.sort(engaged, function(a, b) return a.x < b.x end)
    local maxTargets = (run.mode == "charge") and 8 or 4
    local n = math.min(#engaged, maxTargets)
    local each = baseDps / n
    for i = 1, n do
      local target = engaged[i]
      local dmg = each * dt
      -- crit
      if mod.critChance > 0 and run.rng:next() < mod.critChance then
        dmg = dmg * mod.critMul
      end
      target.hp = target.hp - dmg
      -- apply bleed
      if mod.bleedDps > 0 then
        local bdps = mod.bleedDps * mod.bleedDpsMul
        if (target.bleedDps or 0) < bdps then target.bleedDps = bdps end
        target.bleedTimer = mod.bleedDuration * mod.bleedDurationMul
      end
    end
  end
end

function RunState:killRandomSpartans(count)
  Ops.killRandomSpartans(self.run, count)
end

function RunState:updateCombo(dt)
  local run = self.run
  if run.comboTimer > 0 then
    run.comboTimer = run.comboTimer - dt
    if run.comboTimer <= 0 then
      run.combo = 0
    end
  end
end

function RunState:updateBoss(dt)
  local run = self.run
  run.waveClock = run.waveClock + dt
  run.bossStrikeClock = run.bossStrikeClock + dt

  local bossDps = (run.mode == "charge" and tuning.spartan.chargeDps or tuning.spartan.holdDps)
  bossDps = bossDps * (run.mode == "charge" and run.mod.chargeDpsMul or run.mod.holdDpsMul)
  if run.burst then
    bossDps = bossDps * tuning.rage.burstMultiplier
    run.rage = math.max(0, run.rage - tuning.rage.chargeDrain * dt)
    if run.rage <= 0 then run.burst = false end
  end

  run.bossHP = math.max(0, run.bossHP - bossDps * dt)

  if run.bossStrikeClock >= 2.5 then
    run.bossStrikeClock = run.bossStrikeClock - 2.5
    self:killRandomSpartans(6)
    run.hitFlash = 0.18
    self:addShake(0.12, 6)
    self:addHitstop(0.04)
    self:spawnBlood(tuning.battlefield.leftX + 180, (tuning.battlefield.topY + tuning.battlefield.bottomY) / 2, 30)
    self:emitSfx("boss_strike")
  end

  if run.bossHP <= 0 then
    run.score = run.score + 3000
    self.ctx.manager:switch(GameOverState.new(self.ctx, {
      score = run.score + run.spartans * tuning.scoring.spartanRemaining,
      wavesCleared = run.wavesCleared,
      spartans = run.spartans,
    }))
  end
end

function RunState:updateFx(dt)
  local run = self.run
  if run.shakeTime > 0 then
    run.shakeTime = math.max(0, run.shakeTime - dt)
    if run.shakeTime <= 0 then run.shakePower = 0 end
  end

  for i = #run.particles, 1, -1 do
    local p = run.particles[i]
    p.life = p.life - dt
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.vy = p.vy + 220 * dt
    if p.life <= 0 then
      table.remove(run.particles, i)
    end
  end
end

function RunState:updateWarnings()
  local run = self.run
  if (not run.warning200) and run.spartans <= 200 then
    run.warning200 = true
    run.warningText = "200 SPARTANS LEFT"
    run.warningTime = 1.5
    self:addShake(0.1, 4)
    self:emitSfx("warning")
  elseif (not run.warning100) and run.spartans <= 100 then
    run.warning100 = true
    run.warningText = "100 SPARTANS LEFT"
    run.warningTime = 1.8
    self:addShake(0.12, 5)
    self:emitSfx("warning")
  elseif (not run.warning50) and run.spartans <= 50 then
    run.warning50 = true
    run.warningText = "50 SPARTANS LEFT"
    run.warningTime = 2.0
    self:addShake(0.16, 6)
    self:emitSfx("warning")
  end
end

function RunState:updateFrontAdvance(dt)
  local run = self.run
  local target = (run.mode == "charge") and 170 or 0
  local rate = 6
  local delta = target - run.frontAdvance
  run.frontAdvance = run.frontAdvance + delta * math.min(1, dt * rate)
end

function RunState:update(dt)
  local run = self.run

  if run.paused then return end

  if run.hitstop > 0 then
    run.hitstop = math.max(0, run.hitstop - dt)
    dt = dt * 0.12
  end

  run.time = run.time + dt
  run.score = run.score + tuning.scoring.survivePerSecond * dt
  self:updateFrontAdvance(dt)

  if run.hitFlash > 0 then run.hitFlash = math.max(0, run.hitFlash - dt) end
  if run.warningTime > 0 then run.warningTime = math.max(0, run.warningTime - dt) end

  if run.inBoss then
    self:updateBoss(dt)
  else
    self:updateWaveSpawns(dt)
    self:updateEnemies(dt)
    self:applySpartanDamage(dt)

    local wave = self:currentWave()
    local spawnsDone = run.spawnCursor > #wave.spawns
    if spawnsDone and #run.enemies == 0 then
      run.wavesCleared = run.wavesCleared + 1
      run.score = run.score + tuning.scoring.waveClear
      self:emitSfx("wave_clear")
      run.waveIndex = run.waveIndex + 1
      if run.waveIndex > #waves then
        run.inBoss = true
        run.enemies = {}
        run.waveClock = 0
      else
        local choices = self:pickBoons(3)
        self.ctx.manager:switch(BoonPickState.new(self.ctx, { run = run, choices = choices }))
        return
      end
    end
  end

  self:updateCombo(dt)
  run.spartans = self:spartansAlive()
  self:updateWarnings()
  self:updateFx(dt)

  if run.spartans <= 0 then
    self.ctx.manager:switch(GameOverState.new(self.ctx, {
      score = run.score,
      wavesCleared = run.wavesCleared,
      spartans = 0,
    }))
  end
end

function RunState:drawStrait()
  local bf = tuning.battlefield
  local frontX = self:staticFrontX()
  local farX = bf.rightX + 40
  local samples = 30
  local topRoof = bf.topY - 80
  local botFloor = bf.bottomY + 80

  love.graphics.setColor(0.10, 0.07, 0.06)

  -- Top cliff: filled with vertical strips so polygon stays convex per-strip
  local prevX = frontX
  local prevTopB = select(1, self:corridorBounds(frontX))
  for i = 1, samples do
    local x = frontX + (farX - frontX) * (i / samples)
    local topB = select(1, self:corridorBounds(x))
    love.graphics.polygon("fill", prevX, topRoof, x, topRoof, x, topB, prevX, prevTopB)
    prevX, prevTopB = x, topB
  end

  -- Bottom cliff
  prevX = frontX
  local _, prevBotB = self:corridorBounds(frontX)
  for i = 1, samples do
    local x = frontX + (farX - frontX) * (i / samples)
    local _, botB = self:corridorBounds(x)
    love.graphics.polygon("fill", prevX, prevBotB, x, botB, x, botFloor, prevX, botFloor)
    prevX, prevBotB = x, botB
  end

  -- Inner edge highlight (rim of the pass)
  love.graphics.setColor(0.26, 0.16, 0.10)
  love.graphics.setLineWidth(2)
  local edgeTop = {}
  local edgeBot = {}
  for i = 0, samples do
    local x = frontX + (farX - frontX) * (i / samples)
    local tb, bb = self:corridorBounds(x)
    table.insert(edgeTop, x); table.insert(edgeTop, tb)
    table.insert(edgeBot, x); table.insert(edgeBot, bb)
  end
  love.graphics.line(edgeTop)
  love.graphics.line(edgeBot)
  love.graphics.setLineWidth(1)
end

function RunState:drawBattlefield()
  local bf = tuning.battlefield
  local run = self.run

  -- Spartan camp panel (left of phalanx)
  love.graphics.setColor(0.10, 0.05, 0.05)
  love.graphics.rectangle("fill", bf.leftX, bf.topY - 50, 470, bf.bottomY - bf.topY + 100)
  -- strait floor (right of phalanx)
  love.graphics.setColor(0.16, 0.10, 0.08)
  love.graphics.rectangle("fill", bf.leftX + 480, bf.topY - 50, bf.rightX - (bf.leftX + 480), bf.bottomY - bf.topY + 100)

  -- cliffs of the strait
  self:drawStrait()

  -- phalanx: per-row, drawn from front (col 24) back. Front line stays at col 24.
  local startX, startY = self:phalanxLayout()
  local spacingX, spacingY = PHALANX_SPACING_X, PHALANX_SPACING_Y
  local cols = PHALANX_COLS
  local advance = run.frontAdvance or 0

  for r = 1, PHALANX_ROWS do
    local size = run.rows[r]
    for c = 0, size - 1 do
      local col = (cols - 1) - c
      local isFront = (c == 0)
      local x = startX + col * spacingX + (isFront and advance or 0)
      local y = startY + (r - 1) * spacingY
      if isFront then
        love.graphics.setColor(1.0, 0.55, 0.25)
        love.graphics.rectangle("fill", x - 1, y - 1, 8, 8)
      else
        if run.mode == "charge" then
          love.graphics.setColor(0.95, 0.35, 0.25)
        else
          love.graphics.setColor(0.85, 0.25, 0.25)
        end
        love.graphics.rectangle("fill", x, y, 6, 6)
      end
    end
  end

  -- enemies (continuous y from Gaussian, no lanes)
  for _, e in ipairs(run.enemies) do
    love.graphics.setColor(e.color)
    love.graphics.rectangle("fill", e.x, e.y - 8, 14, 16)
  end

  -- boss
  if run.inBoss then
    love.graphics.setColor(enemyData.godking.color)
    love.graphics.rectangle("fill", bf.rightX - 150, bf.topY + 20, 120, bf.bottomY - bf.topY - 40)
  end

  -- hit flash
  if run.hitFlash > 0 then
    love.graphics.setColor(0.8, 0.1, 0.1, run.hitFlash)
    love.graphics.rectangle("fill", 0, 0, self.ctx.view.W, self.ctx.view.H)
  end
end

function RunState:drawBoonsHud()
  local run = self.run
  if not run.boons or #run.boons == 0 then return end
  local v = self.ctx.view
  local f = self.ctx.fonts
  love.graphics.setFont(f.sm)

  -- Aggregate stacked boons
  local order, byId = {}, {}
  for _, b in ipairs(run.boons) do
    if not byId[b.id] then
      byId[b.id] = { name = b.name, count = 0, archetype = b.archetype, rarity = b.rarity }
      table.insert(order, b.id)
    end
    byId[b.id].count = byId[b.id].count + 1
  end

  local x = 24
  local y = v.H - 28
  love.graphics.setColor(0.7, 0.62, 0.5)
  love.graphics.print("BOONS", x, y - 20)

  local boonModule = require("src.data.boons")
  local cursorX = x
  for _, id in ipairs(order) do
    local b = byId[id]
    local label = b.name .. (b.count > 1 and (" x" .. b.count) or "")
    local archColor = boonModule.archColor(b.archetype)
    local rarColor = boonModule.rarityColor(b.rarity)
    local tw = f.sm:getWidth(label) + 16
    if cursorX + tw > v.W - 24 then break end

    love.graphics.setColor(archColor[1], archColor[2], archColor[3], 0.25)
    love.graphics.rectangle("fill", cursorX, y, tw, 22)
    love.graphics.setColor(rarColor)
    love.graphics.rectangle("line", cursorX, y, tw, 22)
    love.graphics.setColor(0.95, 0.88, 0.72)
    love.graphics.print(label, cursorX + 8, y + 4)
    cursorX = cursorX + tw + 8
  end
end

function RunState:drawUI()
  local run = self.run
  local v = self.ctx.view
  local w, h = v.W, v.H
  local f = self.ctx.fonts

  love.graphics.setFont(f.sm)
  love.graphics.setColor(0.95, 0.85, 0.7)
  love.graphics.print("SPARTANS: " .. math.floor(run.spartans), 24, 22)
  love.graphics.print("MODE: " .. string.upper(run.mode), 24, 50)
  love.graphics.print("WAVE: " .. (run.inBoss and "GOD KING" or tostring(run.waveIndex) .. "/" .. tostring(#waves)), 24, 78)
  love.graphics.print("SCORE: " .. math.floor(run.score), 24, 106)
  love.graphics.print("COMBO: x" .. tostring(run.combo), 24, 134)

  -- rage bar
  love.graphics.setColor(0.2, 0.1, 0.1)
  love.graphics.rectangle("fill", w - 320, 24, 280, 20)
  love.graphics.setColor(0.8, 0.2, 0.2)
  love.graphics.rectangle("fill", w - 320, 24, 280 * (run.rage / tuning.rage.max), 20)
  love.graphics.setColor(0.95, 0.85, 0.7)
  love.graphics.rectangle("line", w - 320, 24, 280, 20)
  love.graphics.print("RAGE", w - 320, 50)

  if run.rage >= tuning.rage.max and not run.burst then
    love.graphics.setColor(0.95, 0.6, 0.3)
    love.graphics.print("RAGE READY - HOLD CHARGE", w - 320, 72)
  elseif run.burst then
    love.graphics.setColor(1.0, 0.7, 0.2)
    love.graphics.print("RAGE BURST ACTIVE", w - 320, 72)
  end

  if run.inBoss then
    love.graphics.setColor(0.2, 0.1, 0.1)
    love.graphics.rectangle("fill", w - 320, 102, 280, 20)
    love.graphics.setColor(1.0, 0.8, 0.2)
    local pct = run.bossHP / enemyData.godking.hp
    love.graphics.rectangle("fill", w - 320, 102, 280 * pct, 20)
    love.graphics.setColor(0.95, 0.85, 0.7)
    love.graphics.rectangle("line", w - 320, 102, 280, 20)
    love.graphics.print("GOD KING", w - 320, 128)
  end

  if run.warningTime > 0 then
    local alpha = math.min(1, run.warningTime)
    love.graphics.setFont(f.md)
    love.graphics.setColor(1.0, 0.2, 0.2, alpha)
    love.graphics.printf(run.warningText, 0, h * 0.16, w, "center")
    love.graphics.setFont(f.sm)
  end

  if run.paused then
    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, w, h)
    love.graphics.setColor(0.95, 0.9, 0.7)
    love.graphics.printf("PAUSED", 0, h * 0.45, w, "center")
    love.graphics.printf("Press P to resume", 0, h * 0.52, w, "center")
  end

  self:drawBoonsHud()
end

function RunState:drawParticles()
  local run = self.run
  for _, p in ipairs(run.particles) do
    love.graphics.setColor(0.85, 0.1, 0.1, math.max(0, p.life / p.maxLife))
    love.graphics.rectangle("fill", p.x, p.y, p.s, p.s)
  end
end

function RunState:draw()
  local run = self.run
  local ox, oy = 0, 0
  if run.shakeTime > 0 and run.shakePower > 0 then
    ox = run.rng:range(-100, 100) / 100 * run.shakePower
    oy = run.rng:range(-100, 100) / 100 * run.shakePower
  end

  love.graphics.push()
  love.graphics.translate(ox, oy)
  self:drawBattlefield()
  self:drawParticles()
  self:drawUI()
  love.graphics.pop()
end

function RunState:spawnBlood(x, y, amount)
  local run = self.run
  for _ = 1, amount do
    local vx = run.rng:range(-120, 120)
    local vy = run.rng:range(-180, -20)
    table.insert(run.particles, {
      x = x,
      y = y,
      vx = vx,
      vy = vy,
      s = run.rng:range(2, 4),
      life = run.rng:range(20, 50) / 100,
      maxLife = run.rng:range(20, 50) / 100,
    })
  end
end

function RunState:addShake(time, power)
  local run = self.run
  run.shakeTime = math.max(run.shakeTime, time)
  run.shakePower = math.max(run.shakePower, power)
end

function RunState:addHitstop(time)
  local run = self.run
  run.hitstop = math.max(run.hitstop, time)
end

function RunState:setCharge(active)
  local run = self.run
  run.chargeHeld = active
  run.mode = active and "charge" or "hold"

  if active and run.rage >= tuning.rage.max and not run.burst then
    run.burst = true
    self:addShake(0.12, 5)
    self:addHitstop(0.06)
    self:spawnBlood(tuning.battlefield.leftX + 220, (tuning.battlefield.topY + tuning.battlefield.bottomY) / 2, 40)
    self:emitSfx("burst")
  elseif not active then
    run.burst = false
  end
end

function RunState:keypressed(key)
  if key == "p" then
    self.run.paused = not self.run.paused
    return
  end

  if self.run.paused then return end

  if key == "space" then
    self:setCharge(true)
  elseif key == "escape" then
    self.ctx.manager:switch(GameOverState.new(self.ctx, {
      score = self.run.score,
      wavesCleared = self.run.wavesCleared,
      spartans = self.run.spartans,
    }))
  end
end

function RunState:keyreleased(key)
  if self.run.paused then return end
  if key == "space" then
    self:setCharge(false)
  end
end

function RunState:mousepressed(_, _, button)
  if self.run.paused then return end
  if button == 1 then
    self:setCharge(true)
  end
end

function RunState:mousereleased(_, _, button)
  if self.run.paused then return end
  if button == 1 then
    self:setCharge(false)
  end
end

function RunState:leave()
  -- reset sticky charge if switching states while held
  self:setCharge(false)
end

return RunState
