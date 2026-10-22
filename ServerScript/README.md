# ServerScript

Maps to **ServerScriptService** in Studio.

- `SurvivalServer.server.lua` — init only (~55 lines). Picks the world seed, builds the seeded world (terrain, trees from `Assets.Tree`, the spawn campfire from `Assets.BonFire` when present), starts the ONE server-wide `DayNightClock` and `Temperature`, then starts `Gameplay` (players, tools, logs, digging), the shared `DragSystem`, and `SledService` (the sled and its cargo). Ticks the whole simulation every 0.25s. All logic lives in the modules under `ServerStorage/Modules` — this script only wires them together.
