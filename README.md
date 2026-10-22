# Survival100daysInArtic

Survive 100 Days in the Arctic — a Roblox survival game. Design doc lives outside this repo (ask Arzh for DESIGN.md).

## Layout

| Folder | Goes to in Studio | Holds |
|---|---|---|
| `ReplicatedStorage/` | ReplicatedStorage | Shared modules (Config, Signal) used by server and client |
| `ServerStorage/` | ServerStorage | Server-only modules (core clock, temperature, hunger, survival) |
| `ServerScript/` | ServerScriptService | The server script — init only; all logic lives in modules |
| `PlayerScripts/` | StarterPlayer > StarterPlayerScripts | Client scripts (HUD, input — later phases) |
| `Others/` | not synced | Models, meshes, and other raw assets |

`default.project.json` is a Rojo project file that maps these folders into the tree above. Copy-pasting the folders into Studio by hand works too.

## Sync rules

- **Rojo sync is narrow on purpose.** `default.project.json` maps only `ReplicatedStorage/Modules`, `ServerStorage/Modules`, and the two runtime scripts (`SurvivalServer`, `SurvivalClient`). Everything else in Studio — the `Assets` folder, spare models, anything you add by hand — is outside Rojo's reach and never gets deleted by a sync.

## Architecture rules

- **One clock per server.** `DayNightClock` and `Temperature` are singletons — the server script creates exactly one of each and every player's `SurvivalPlayer` shares them. Day, night, day count, multiplier and weather are identical for everyone; per-player clocks would desync the yeti, storms and night events.
- **Only bodies are per-player.** Health, warmth, hunger and sickness live in `SurvivalPlayer`, one instance per player.

## Status

**Phase 1 — Core clock (complete).** Runtime is live on the `Phase1` branch: the server script picks a seed, builds the terrain, starts the one server-wide clock, and spawns a `SurvivalPlayer` per player. Playable now: day/night cycle, weather, chopping (a felled tree drops physical WoodLog pieces — drag them to camp or load them on the sled; heavier logs slow your movement), campfire warmth and feeding, sprint (2x hunger drain), freeze / starve / sick / die, and the HUD. Tuning: hunger caps at 50 and cold drains warmth fast — the fire matters. Trees and logs come from the models in `ReplicatedStorage/Assets` (`Tree`, `WoodLog`) — there are no code-built placeholder models.

**Phase 2 — Dig, Fire, Wolf (in progress, branch `Phase2`).** No placed buildings: a starter shovel carves snow caves into the terrain (the campfire never moves — you dig your base inside its warm circle). The campfire levels up as physical logs are fed into it (levels 1–7, burn value in `Config.Campfire.LevelBurnUnits`), growing a visible warm ring from 18 to 50 studs and a BillboardGui readout (level, fuel bar, radius). HUD gained the hotbar. The sled is in: it spawns by the camp from `Assets.Sled`/`sled` (the `RedaPart` box is the cargo zone — hidden in game, pieces stack inside it, 100kg cap), and players pull it with two hand ropes on a trailer follow, speed taxed by total weight. Still to come in this phase: fishing-lite, wolf taming, and wolf-pulled riding.

- `DayNightClock` — day/night cycle (3 min day, 2 min night), day counter, day multiplier.
- `Temperature` — weather (Clear / Storm / Blizzard), ambient temperature, cold exposure rates.
- `Hunger` — hunger value, drain (sprinting drains 2x), starving state.
- `SurvivalPlayer` — one player's health / warmth / hunger / sickness, ticked together.
- `WorldBuilder` — builds the world: terrain (skippable via `Config.World.GenerateTerrain` for hand-made maps), tree planting with seeded size variety, the campfire, ground-height lookups, and the shared HUD world state.
- `Gameplay` — players and interaction: survival ticking, the axe, tree shake/fall (a felled tree drops log pieces — bigger, thicker trees drop more, up to 10; pieces are ground-snapped, draggable with weight-based slowdown, and chop into wood by volume), and sprint.
- `Seed` — deterministic RNG from a 5–8 letter seed string. `Fork("lake")` gives each feature its own stream, so changing one feature never reshuffles the others. Same seed = same numbers, always.
- `WorldGen` — turns a seed into a world layout (data only): mountain, frozen lake, tree spots, cabin spots, plus reserved coal and yeti-cave spots for later phases.
- `TerrainBuilder` — paints a layout into Workspace Terrain: snow base, rock mountain with a snow cap, carved lake with a glacier surface.
- `Config` — every tuning number in one place, including the animation ID table.
- `Signal` — tiny event helper the modules use instead of BindableEvents.
