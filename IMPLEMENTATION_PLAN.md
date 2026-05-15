# PHALANX / 300 — Lua (LÖVE 2D) Implementation Plan

## 0) Target

Build a playable MVP where the core loop works:
- Start run with 300 Spartans
- HOLD vs CHARGE gameplay
- Enemy waves
- Rage meter
- Boon pick between waves
- God King final encounter
- Score + retry loop

---

## 1) Tech stack

- Engine: **LÖVE 11.x**
- Language: **Lua 5.1 (LuaJIT)**
- Libraries:
  - `push` (virtual resolution)
  - `flux` (tweens)
  - optional `hump.gamestate` (or custom state manager)

Project style:
- data-driven config tables (`data/*.lua`)
- thin update/render loops
- deterministic seeded RNG per run

---

## 2) Folder structure

```txt
/src
  main.lua
  conf.lua
  /core
    game.lua
    state_manager.lua
    rng.lua
    timer.lua
    input.lua
  /states
    boot.lua
    menu.lua
    run.lua
    boon_pick.lua
    game_over.lua
  /systems
    combat_system.lua
    wave_system.lua
    rage_system.lua
    boon_system.lua
    score_system.lua
    fx_system.lua
    ui_system.lua
  /entities
    spartan_line.lua
    enemy.lua
    god_king.lua
  /data
    boons.lua
    enemies.lua
    waves.lua
    tuning.lua
  /render
    battlefield_view.lua
    ui_view.lua
    fx_view.lua
/assets
  /sfx
  /music
  /fonts
```

---

## 3) State flow

1. `menu` → start run
2. `run` (combat/waves)
3. wave clear → `boon_pick`
4. back to `run`
5. after last wave → `run` with God King mode
6. death or boss end → `game_over`
7. retry/new run

---

## 4) Data model (minimal)

## RunState
- `spartans_left` (int, start 300)
- `mode` (`"hold" | "charge"`)
- `rage` (0..100)
- `combo` (int)
- `score` (int)
- `wave_index` (int)
- `boons` (array)
- `seed` (int)

## SpartanLine
- `front_hp` (abstract line durability)
- `hold_dps`
- `charge_dps`
- `hold_loss_rate`
- `charge_loss_rate`

## Enemy
- `type`
- `hp`
- `speed`
- `damage`
- `x`, `lane`

---

## 5) Core systems

## 5.1 Input system
- Press/hold Space (or LMB) = CHARGE
- Release = HOLD

## 5.2 Combat system
Per frame:
- apply Spartan DPS to nearby enemies
- remove dead enemies
- tick combo window and combo decay
- apply enemy contact damage to Spartan line
- convert line damage into Spartan deaths (`spartans_left` decrement)

## 5.3 Rage system
- kills add rage
- combo adds rage multiplier
- if rage full and CHARGE active: burst modifier enabled
- rage drains while burst active

## 5.4 Wave system
- spawn schedule from `data/waves.lua`
- wave ends when schedule complete and enemies == 0
- emit `WAVE_CLEARED`

## 5.5 Boon system
- on `WAVE_CLEARED`, roll 3 boons from pool
- choose one, apply modifiers to run stats

## 5.6 God King mode
- swap wave spawner for boss entity
- periodic boss attacks kill fixed Spartans
- player deals DPS until wipe or boss timer end
- score bonus from boss damage

## 5.7 Score system
Update continuously:
- enemy kills
- survival time
- combo peak
- god king damage
- spartans remaining bonus at end

---

## 6) Gameplay tuning constants

In `data/tuning.lua`:
- base hold dps / loss rate
- base charge dps / loss rate
- rage gain per kill
- combo timeout
- enemy spawn cadence per wave
- boss hp and attack cadence

Keep all balance in data, not hardcoded in systems.

---

## 7) Milestones

## M1 — Playable combat sandbox (1–2 days)
- One wave spawner
- HOLD/CHARGE switching
- Spartan count decreases
- Basic score and restart

## M2 — Full run loop (2–3 days)
- Multiple waves
- Wave clear detection
- Boon pick screen and boon effects
- Game over + retry

## M3 — Rage + juice (2 days)
- Rage meter + burst
- Hit-stop, screen shake, blood particles
- Combo behavior + SFX hooks

## M4 — God King + scoring (1–2 days)
- Boss encounter state in run
- Boss pressure attacks
- End-of-run score breakdown

## M5 — Polish pass (2–4 days)
- UI clarity
- audio mix pass
- difficulty curve pass
- bug fixing + balancing

---

## 8) Testing checklist

Per build verify:
- Spartan count never goes negative
- HOLD always safer than CHARGE (per second casualty rate)
- CHARGE always meaningfully faster for clears
- Rage burst is noticeable and worth using
- Every wave can be cleared with baseline tuning
- At least 3 viable boon archetypes emerge
- Run duration target: 12–20 min MVP

---

## 9) Risks + mitigations

1. **Feels shallow fast**
   - Mitigate: stronger boon interactions and enemy mix
2. **Charge is always best or always worst**
   - Mitigate: tune casualty/dps ratio by wave tier
3. **Unreadable battlefield chaos**
   - Mitigate: reduce unit count on screen; keep deaths as aggregate while preserving 300 counter
4. **No emotional weight to losses**
   - Mitigate: UI pulse and audio cue every 10 Spartans lost, milestone warnings at 200/100/50

---

## 10) Immediate next tasks (today)

1. Create folder scaffold and `main.lua` boot.
2. Implement `run` state with:
   - spartans counter
   - hold/charge toggle
   - single enemy type and spawner
3. Add simple text UI for:
   - Spartans left
   - Rage
   - Wave
4. Add game over when Spartans hit 0.

Once this is fun, add boons. Not before.
