# PHALANX / 300 — MVP SPEC (Arcade Core)

> Working title: **300**
> Goal: strip to pure action, blood, progression, dopamine.

---

## 1) Fantasy

You begin each run with **300 Spartans**.
They die permanently during the run.
You hold the line against endless Persian waves and push for a high score.

---

## 2) Core Pillars

1. **300 is the resource** (always visible, always shrinking).
2. **Immediate action** (no heavy puzzle layer).
3. **Brutal trade-offs** (power now costs lives now).
4. **Run progression** (boons each wave, boss at the end).
5. **Juice first** (blood bursts, hit-stop, screen shake, audio escalation).

---

## 3) Core Loop (10–30s)

1. Persians advance from right to left.
2. Spartans auto-attack while in **HOLD** mode.
3. Player triggers **CHARGE** windows for burst damage.
4. Enemies die, blood sprays, combo rises, Rage fills.
5. Spartans die from contact and enemy attacks.
6. Wave ends → pick 1 of 3 boons.
7. Repeat until wipe or God King.

---

## 4) Controls (minimal)

- **Hold Line**: default state.
- **Charge**: press/hold key (e.g. Space / LMB).

Optional extra (if needed after playtest):
- **Brace** (short cooldown defensive state).

MVP should ship with only HOLD + CHARGE.

---

## 5) Combat Model

### 5.1 States

- **HOLD**
  - Lower outgoing damage
  - Lower Spartan casualties
  - Stable Rage gain

- **CHARGE**
  - High outgoing damage / cleave
  - High Spartan casualties
  - Large blood and combo generation

### 5.2 Spartan deaths

A Spartan can die from:
- Direct contact in melee lane
- Ranged enemy hit
- Collateral during charge

All deaths are permanent for the run.

---

## 6) Rage + Combo (dopamine engine)

- **Combo** increases on rapid kills.
- **Rage meter** fills from kills and combo thresholds.
- At full Rage, player can trigger **Rage Charge**:
  - brief slow-mo entry
  - big damage multiplier
  - high blood burst
  - audio/music accent

Rage is spent on activation and resets.

---

## 7) Waves, Boons, Bosses

### 7.1 Run structure (MVP)

- 8 normal waves
- 2 elite waves (wave 4, wave 8)
- Final: **God King** damage-check encounter

### 7.2 Boon choice

After each cleared wave, choose 1 of 3 random boons.

Boon examples:
- +15% attack speed
- +20% charge damage
- -20% charge self-casualties
- +25% rage gain
- Crits cause bleed splash
- Every 20th kill heals 1 Spartan (cap per wave)

### 7.3 God King

Final encounter is a pure pressure fight:
- huge HP
- periodic lane-wide attacks
- score scales with damage dealt and survivors

---

## 8) Progression

### In-run
- Boons stack each wave
- Build identity emerges (rage build / sustain build / charge build)

### Meta (between runs)
- Unlock new boons into pool
- Unlock starting modifiers (small, non-run-breaking)
- Track best score, best wave, best God King damage

No heavy RPG stat inflation.

---

## 9) Scoring

`Final Score =`
- enemies killed × A
- time survived × B
- God King damage × C
- Spartans remaining × D
- combo peak bonus

Target feeling: surviving with 40 Spartans left should feel legendary.

---

## 10) Visual + Audio Direction (low asset)

### Visual
- Minimal pixel silhouettes
- Red-heavy blood FX and hit flashes
- Big readable UI: `SPARTANS LEFT: ###`
- Screen shake + hit-stop on bursts

### Audio
- Layered drums intensify as Spartan count drops
- Distinct SFX for:
  - kill
  - multikill
  - Rage ready
  - Spartan death tick

---

## 11) MVP Scope

### Must-have
- Single battlefield screen
- HOLD / CHARGE gameplay
- Enemy waves and scaling
- Spartan death accounting from 300
- Rage meter + activation
- Boon draft after wave
- God King final encounter
- Score screen + restart loop

### Nice-to-have (post-MVP)
- Additional enemy archetypes
- Brace action
- Daily seed
- Global leaderboard

---

## 12) Technical

- Engine: **LÖVE 2D (Lua)**
- Deterministic seeded wave generation
- Data-driven boons/enemies via Lua tables
- Save: local JSON for meta progression and highscores

---

## 13) Success Criteria

Game is successful when playtesters say:
1. “I instantly understood it.”
2. “I kept spending Spartans for hype moments.”
3. “I died, hit retry immediately.”
4. “Seeing the number drop from 300 hurt (in a good way).”

---

## 14) Build Order (1–2 week prototype)

1. Spartan count + enemy spawner + auto-combat
2. HOLD vs CHARGE tuning
3. Blood FX + hit-stop + shake
4. Rage meter + Rage Charge
5. Wave clear + boon pick screen
6. Score + restart loop
7. God King placeholder fight

Ship prototype fast, tune feel before content.
