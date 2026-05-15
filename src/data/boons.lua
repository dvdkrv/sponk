return {
  {
    id = "hold_dps_up",
    name = "Bronze Discipline",
    desc = "+20% HOLD damage",
    apply = function(run)
      run.mod.holdDpsMul = run.mod.holdDpsMul * 1.2
    end,
  },
  {
    id = "charge_dps_up",
    name = "Blood Frenzy",
    desc = "+25% CHARGE damage",
    apply = function(run)
      run.mod.chargeDpsMul = run.mod.chargeDpsMul * 1.25
    end,
  },
  {
    id = "charge_loss_down",
    name = "Shield Bracing",
    desc = "-25% CHARGE casualties",
    apply = function(run)
      run.mod.chargeLossMul = run.mod.chargeLossMul * 0.75
    end,
  },
  {
    id = "hold_loss_down",
    name = "Locked Ranks",
    desc = "-20% HOLD casualties",
    apply = function(run)
      run.mod.holdLossMul = run.mod.holdLossMul * 0.8
    end,
  },
  {
    id = "rage_gain_up",
    name = "War Drums",
    desc = "+35% Rage gain",
    apply = function(run)
      run.mod.rageGainMul = run.mod.rageGainMul * 1.35
    end,
  },
  {
    id = "survivor_gift",
    name = "Medic Fires",
    desc = "Recover 15 Spartans now",
    apply = function(run)
      run.spartans = math.min(300, run.spartans + 15)
    end,
  },
}
