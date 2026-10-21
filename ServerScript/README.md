# ServerScript

Maps to **ServerScriptService** in Studio.

- `SurvivalServer.server.lua` — the Phase 1 runtime. Builds the seeded world (terrain + placeholder pines + spawn campfire), creates the ONE server-wide `DayNightClock` and `Temperature`, hands every player a `SurvivalPlayer` bound to them, drives Lighting from the clock, rolls weather on phase changes, and ticks survival every 0.25s. Also creates the starter Axe in StarterPack, the chopping logic, the campfire feed prompt (1 wood = +45s of fire), and the `Remotes/SetSprinting` event the client fires.
