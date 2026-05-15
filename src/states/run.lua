local RNG = require("src.core.rng")
local tuning = require("src.data.tuning")
local enemyData = require("src.data.enemies")
local waves = require("src.data.waves")
local boons = require("src.data.boons")

local BoonPickState = require("src.states.boon_pick")
local GameOverState = require("src.states.game_over")

local RunState = {}
RunState.__index = RunState

local function laneY(index)
  local bf = tuning.battlefield
  local step = (bf.bottomY - bf.topY) / (bf.laneCount - 1)
  return bf.topY + (index - 1) * step
end

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
      mod = {
        holdDpsMul = 1,
        chargeDpsMul = 1,
        holdLossMul = 1,
        chargeLossMul = 1,
        rageGainMul = 1,
      },
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
    }
  end

  self:initWaveIfNeeded()
  return self
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

function RunState:spawnEnemy(kind)
  local run = self.run
  local lane = run.rng:range(1, tuning.battlefield.laneCount)
  local data = enemyData[kind]
  local scale = 1 + (run.waveIndex - 1) * 0.12
  table.insert(run.enemies, {
    type = kind,
    hp = data.hp * scale,
    speed = data.speed * (1 + (run.waveIndex - 1) * 0.04),
    damage = data.damage * scale,
    score = data.score,
    lane = lane,
    x = tuning.battlefield.rightX,
    color = data.color,
  })
end

function RunState:pickBoons(n)
  local run = self.run
  local picked, used = {}, {}
  while #picked < n do
    local idx = run.rng:range(1, #boons)
    if not used[idx] then
      used[idx] = true
      table.insert(picked, boons[idx])
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

  self:spawnBlood(e.x, laneY(e.lane), 6 + e.score * 2)
  self:addShake(0.05, 2 + e.score)
  self:addHitstop(0.02)
  self:emitSfx("kill")
end

function RunState:updateEnemies(dt)
  local run = self.run
  local frontX = tuning.battlefield.leftX + 160
  for i = #run.enemies, 1, -1 do
    local e = run.enemies[i]
    e.x = e.x - e.speed * dt
    if e.x <= frontX then
      run.pendingDeaths = run.pendingDeaths + e.damage * dt
      run.hitFlash = 0.12
      self:addShake(0.03, 2)
    end
    if e.x <= tuning.battlefield.leftX - 40 or e.hp <= 0 then
      if e.hp <= 0 then
        self:onEnemyKilled(e)
      end
      table.remove(run.enemies, i)
    end
  end
end

function RunState:applySpartanDamage(dt)
  local run = self.run
  local baseDps = tuning.spartan.holdDps
  local lossRate = tuning.spartan.holdLossRate

  if run.mode == "charge" then
    baseDps = tuning.spartan.chargeDps
    lossRate = tuning.spartan.chargeLossRate
    baseDps = baseDps * run.mod.chargeDpsMul
    lossRate = lossRate * run.mod.chargeLossMul
  else
    baseDps = baseDps * run.mod.holdDpsMul
    lossRate = lossRate * run.mod.holdLossMul
  end

  if run.burst then
    baseDps = baseDps * tuning.rage.burstMultiplier
    run.rage = math.max(0, run.rage - tuning.rage.chargeDrain * dt)
    if run.rage <= 0 then run.burst = false end
  end

  -- distribute damage over nearest enemies in each lane
  local perLane = {}
  for lane = 1, tuning.battlefield.laneCount do
    perLane[lane] = baseDps / tuning.battlefield.laneCount
  end

  for lane = 1, tuning.battlefield.laneCount do
    local target = nil
    for _, e in ipairs(run.enemies) do
      if e.lane == lane then
        if not target or e.x < target.x then
          target = e
        end
      end
    end
    if target then
      target.hp = target.hp - perLane[lane] * dt
    end
  end

  run.pendingDeaths = run.pendingDeaths + lossRate * dt
end

function RunState:resolveSpartanDeaths()
  local run = self.run
  if run.pendingDeaths >= 1 then
    local deaths = math.floor(run.pendingDeaths)
    run.pendingDeaths = run.pendingDeaths - deaths
    run.spartans = math.max(0, run.spartans - deaths)
  end
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

  local passiveLoss = (run.mode == "charge" and tuning.spartan.chargeLossRate or tuning.spartan.holdLossRate)
  passiveLoss = passiveLoss * (run.mode == "charge" and run.mod.chargeLossMul or run.mod.holdLossMul)
  run.pendingDeaths = run.pendingDeaths + passiveLoss * dt

  if run.bossStrikeClock >= 2.5 then
    run.bossStrikeClock = run.bossStrikeClock - 2.5
    run.spartans = math.max(0, run.spartans - 6)
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

function RunState:update(dt)
  local run = self.run

  if run.paused then return end

  if run.hitstop > 0 then
    run.hitstop = math.max(0, run.hitstop - dt)
    dt = dt * 0.12
  end

  run.time = run.time + dt
  run.score = run.score + tuning.scoring.survivePerSecond * dt

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
  self:resolveSpartanDeaths()
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

function RunState:drawBattlefield()
  local bf = tuning.battlefield
  local run = self.run

  -- battlefield panels
  love.graphics.setColor(0.10, 0.05, 0.05)
  love.graphics.rectangle("fill", bf.leftX, bf.topY - 50, 450, bf.bottomY - bf.topY + 100)
  love.graphics.setColor(0.13, 0.06, 0.08)
  love.graphics.rectangle("fill", bf.leftX + 460, bf.topY - 50, bf.rightX - (bf.leftX + 460), bf.bottomY - bf.topY + 100)

  -- lanes
  for lane = 1, bf.laneCount do
    local y = laneY(lane)
    love.graphics.setColor(0.2, 0.1, 0.1)
    love.graphics.rectangle("fill", bf.leftX, y - 3, bf.rightX - bf.leftX, 6)
  end

  -- front line
  love.graphics.setColor(0.76, 0.15, 0.15)
  love.graphics.rectangle("fill", bf.leftX + 140, bf.topY - 20, 18, bf.bottomY - bf.topY + 40)

  -- spartans as dots (capped visual count)
  local visual = math.min(run.spartans, 300)
  local cols = 30
  local spacingX, spacingY = 12, 12
  local startX, startY = bf.leftX + 20, bf.topY
  for i = 1, visual do
    local col = (i - 1) % cols
    local row = math.floor((i - 1) / cols)
    local x = startX + col * spacingX
    local y = startY + row * spacingY
    love.graphics.setColor(0.85, 0.25, 0.25)
    love.graphics.rectangle("fill", x, y, 6, 6)
  end

  -- enemies
  for _, e in ipairs(run.enemies) do
    local y = laneY(e.lane)
    love.graphics.setColor(e.color)
    love.graphics.rectangle("fill", e.x, y - 10, 18, 20)
  end

  -- boss
  if run.inBoss then
    love.graphics.setColor(enemyData.godking.color)
    love.graphics.rectangle("fill", bf.rightX - 150, bf.topY + 20, 120, bf.bottomY - bf.topY - 40)
  end

  -- hit flash
  if run.hitFlash > 0 then
    love.graphics.setColor(0.8, 0.1, 0.1, run.hitFlash)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
  end
end

function RunState:drawUI()
  local run = self.run
  local w, h = love.graphics.getDimensions()
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
