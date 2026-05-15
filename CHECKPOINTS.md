# Implementation Checkpoints

## M1 — Playable combat sandbox ✅

Completed:
- LÖVE project scaffold (`main.lua`, `conf.lua`, `src/*`)
- `run` state with core battlefield simulation
- Spartan counter starts at 300 and decreases from combat pressure
- HOLD / CHARGE input (Space or LMB)
- Single-screen combat rendering
- Game over transition when Spartans reach 0

Notes:
- This milestone is playable as a sandbox loop.

---

## M2 — Full run loop ✅

Completed:
- Multi-wave progression from `src/data/waves.lua`
- Wave clear detection
- Boon draft state (`boon_pick`) with 3 choices
- Boon application to run modifiers
- Return from boon pick back into combat
- Menu and game-over states with retry/menu flow

Notes:
- Full run structure is in place before final boss.

---

## M4 — God King + scoring (baseline) ✅

Completed:
- God King phase after final wave
- Boss HP bar and timed boss strike pressure
- Player DPS vs boss via HOLD/CHARGE (+ Rage burst)
- End-of-run scoring summary in game-over screen

Notes:
- This is a functional baseline pass; polish and balancing still pending.

---

## M3 — Rage + juice ✅

Completed:
- Rage meter + burst activation
- Combo tracking and combo peak
- Blood particle bursts on kills, burst triggers, and boss strikes
- Screen shake on impacts/kills/burst/boss strike
- Hit-stop on key combat moments
- SFX event hook points (`kill`, `burst`, `boss_strike`) ready for audio assets

---

## M5 — Polish pass ✅

Completed:
- Added persistent meta save (`src/core/save.lua`): best score, best waves, best survivors, run count
- Game over now updates and displays best score + total runs
- Added pause toggle (`P`) with overlay
- Added casualty milestone warnings at 200 / 100 / 50 Spartans
- Added wave-based enemy scaling (HP/speed/damage)
- Added lightweight procedural SFX system (`src/core/audio.lua`) and hooked events:
  - `kill`
  - `burst`
  - `boss_strike`
  - `wave_clear`
  - `warning`
- UI readability pass:
  - centralized fonts in game context
  - larger heading/body hierarchy in menu/game-over/boon screens
  - improved warning prominence in combat
- Edge-case handling:
  - pause now blocks charge/mouse input
  - state transitions continue to reset sticky charge safely
