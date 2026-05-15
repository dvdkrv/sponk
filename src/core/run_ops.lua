local Ops = {}

function Ops.defaultMod()
  return {
    -- Damage
    holdDpsMul = 1,
    chargeDpsMul = 1,
    allDpsMul = 1,
    comboDamageBonus = 0,
    critChance = 0,
    critMul = 2.0,
    lastStandMul = 1.0,
    lastStandThreshold = 0,

    -- Casualties
    holdLossMul = 1,
    chargeLossMul = 1,
    frontLossMul = 1,
    spartanHpMul = 1,

    -- Rage
    rageGainMul = 1,
    burstMulBonus = 0,
    burstDrainMul = 1,

    -- Bleed
    bleedDps = 0,
    bleedDuration = 3,
    bleedDurationMul = 1,
    bleedDpsMul = 1,
  }
end

function Ops.spartansAlive(run)
  local total = 0
  for r = 1, #run.rows do
    total = total + run.rows[r]
  end
  return total
end

function Ops.killRandomSpartans(run, count)
  while count > 0 do
    local alive = {}
    for r = 1, #run.rows do
      if run.rows[r] > 0 then table.insert(alive, r) end
    end
    if #alive == 0 then break end
    local r = alive[run.rng:range(1, #alive)]
    run.rows[r] = run.rows[r] - 1
    count = count - 1
  end
  run.spartans = Ops.spartansAlive(run)
end

function Ops.healSpartans(run, count)
  while count > 0 do
    local minRow, minVal = nil, 26
    for r = 1, #run.rows do
      if run.rows[r] < 25 and run.rows[r] < minVal then
        minRow = r
        minVal = run.rows[r]
      end
    end
    if not minRow then break end
    run.rows[minRow] = run.rows[minRow] + 1
    count = count - 1
  end
  run.spartans = Ops.spartansAlive(run)
end

return Ops
