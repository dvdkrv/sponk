local Ops = require("src.core.run_ops")

-- Boons are categorized by ARCHETYPE so the offer pool can bias toward
-- builds the player has already invested in.
-- Rarity controls draw weight: common 6, uncommon 3, rare 1.
-- `stackable = true` means the boon can be offered (and picked) multiple times.

local function archColor(arch)
  if arch == "bronze" then return { 0.85, 0.65, 0.30 } end
  if arch == "fury"   then return { 0.95, 0.35, 0.25 } end
  if arch == "bleed"  then return { 0.70, 0.10, 0.20 } end
  if arch == "wall"   then return { 0.45, 0.55, 0.75 } end
  if arch == "oracle" then return { 0.75, 0.85, 0.40 } end
  if arch == "cursed" then return { 0.55, 0.20, 0.55 } end
  return { 0.9, 0.85, 0.7 }
end

local function rarityColor(r)
  if r == "common"   then return { 0.92, 0.85, 0.70 } end
  if r == "uncommon" then return { 0.95, 0.78, 0.30 } end
  if r == "rare"     then return { 1.00, 0.50, 0.20 } end
  return { 1, 1, 1 }
end

local boons = {
  -- ============ BRONZE (raw damage) ============
  {
    id = "bronze_edge", name = "Bronze Edge",
    desc = "+25% HOLD damage.",
    archetype = "bronze", rarity = "common", stackable = true,
    apply = function(run) run.mod.holdDpsMul = run.mod.holdDpsMul * 1.25 end,
  },
  {
    id = "brazen_charge", name = "Brazen Charge",
    desc = "+30% CHARGE damage.",
    archetype = "bronze", rarity = "common", stackable = true,
    apply = function(run) run.mod.chargeDpsMul = run.mod.chargeDpsMul * 1.30 end,
  },
  {
    id = "lambdas_wrath", name = "Lambda's Wrath",
    desc = "+12% damage in any mode.",
    archetype = "bronze", rarity = "uncommon", stackable = true,
    apply = function(run) run.mod.allDpsMul = run.mod.allDpsMul * 1.12 end,
  },
  {
    id = "forge_of_sparta", name = "Forge of Sparta",
    desc = "Each combo point adds +0.4% damage.",
    archetype = "bronze", rarity = "rare", stackable = false,
    apply = function(run) run.mod.comboDamageBonus = run.mod.comboDamageBonus + 0.004 end,
  },

  -- ============ FURY (rage / burst) ============
  {
    id = "war_drums", name = "War Drums",
    desc = "+40% rage gained from kills.",
    archetype = "fury", rarity = "common", stackable = true,
    apply = function(run) run.mod.rageGainMul = run.mod.rageGainMul * 1.40 end,
  },
  {
    id = "heart_of_ares", name = "Heart of Ares",
    desc = "Rage burst drains 25% slower.",
    archetype = "fury", rarity = "common", stackable = true,
    apply = function(run) run.mod.burstDrainMul = run.mod.burstDrainMul * 0.75 end,
  },
  {
    id = "lacedaemon_roar", name = "Lacedaemon Roar",
    desc = "Rage burst multiplier +0.6.",
    archetype = "fury", rarity = "uncommon", stackable = true,
    apply = function(run) run.mod.burstMulBonus = run.mod.burstMulBonus + 0.6 end,
  },
  {
    id = "eternal_burst", name = "Eternal Burst",
    desc = "Rage burst drains 80% slower.",
    archetype = "fury", rarity = "rare", stackable = false,
    apply = function(run) run.mod.burstDrainMul = run.mod.burstDrainMul * 0.20 end,
  },

  -- ============ BLEED ============
  {
    id = "spear_bleed", name = "Spear Bleed",
    desc = "Hits cause 2 dps bleed for 3s.",
    archetype = "bleed", rarity = "common", stackable = true,
    apply = function(run)
      run.mod.bleedDps = run.mod.bleedDps + 2.0
    end,
  },
  {
    id = "open_wound", name = "Open Wound",
    desc = "Bleed duration doubled.",
    archetype = "bleed", rarity = "uncommon", stackable = false,
    apply = function(run) run.mod.bleedDurationMul = run.mod.bleedDurationMul * 2 end,
  },
  {
    id = "crimson_tide", name = "Crimson Tide",
    desc = "Bleed damage x3.",
    archetype = "bleed", rarity = "rare", stackable = false,
    apply = function(run) run.mod.bleedDpsMul = run.mod.bleedDpsMul * 3 end,
  },

  -- ============ SHIELD WALL (defensive) ============
  {
    id = "locked_ranks", name = "Locked Ranks",
    desc = "-30% contact casualties.",
    archetype = "wall", rarity = "common", stackable = true,
    apply = function(run)
      run.mod.holdLossMul = run.mod.holdLossMul * 0.70
      run.mod.chargeLossMul = run.mod.chargeLossMul * 0.70
    end,
  },
  {
    id = "bronze_shields", name = "Bronze Shields",
    desc = "Each front-line Spartan takes 2 hits to fell.",
    archetype = "wall", rarity = "uncommon", stackable = false,
    apply = function(run) run.mod.spartanHpMul = run.mod.spartanHpMul * 2 end,
  },
  {
    id = "indomitable", name = "Indomitable",
    desc = "-50% front-line casualties.",
    archetype = "wall", rarity = "rare", stackable = false,
    apply = function(run)
      run.mod.holdLossMul = run.mod.holdLossMul * 0.5
      run.mod.chargeLossMul = run.mod.chargeLossMul * 0.5
    end,
  },

  -- ============ ORACLE (utility / RNG) ============
  {
    id = "medic_fires", name = "Medic Fires",
    desc = "Restore 20 Spartans now.",
    archetype = "oracle", rarity = "common", stackable = true,
    apply = function(run) Ops.healSpartans(run, 20) end,
  },
  {
    id = "apollos_favor", name = "Apollo's Favor",
    desc = "8% chance for 2.5x crit damage.",
    archetype = "oracle", rarity = "uncommon", stackable = true,
    apply = function(run)
      run.mod.critChance = math.min(0.6, run.mod.critChance + 0.08)
      run.mod.critMul = math.max(run.mod.critMul, 2.5)
    end,
  },

  -- ============ CURSED (trade-offs) ============
  {
    id = "blood_pact", name = "Blood Pact",
    desc = "Lose 40 Spartans NOW. +30% damage forever.",
    archetype = "cursed", rarity = "uncommon", stackable = true,
    apply = function(run)
      Ops.killRandomSpartans(run, 40)
      run.mod.allDpsMul = run.mod.allDpsMul * 1.30
    end,
  },
  {
    id = "last_stand", name = "Last Stand",
    desc = "Below 100 Spartans, damage x2.5.",
    archetype = "cursed", rarity = "rare", stackable = false,
    apply = function(run)
      run.mod.lastStandThreshold = math.max(run.mod.lastStandThreshold, 100)
      run.mod.lastStandMul = math.max(run.mod.lastStandMul, 2.5)
    end,
  },
}

return {
  list = boons,
  archColor = archColor,
  rarityColor = rarityColor,
}
