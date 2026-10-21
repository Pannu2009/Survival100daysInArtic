# Survival100daysInArtic

Survive 100 Days in the Arctic — a Roblox survival game. Design doc lives outside this repo (ask Arzh for DESIGN.md).

## Layout

| Folder | Goes to in Studio | Holds |
|---|---|---|
| `ReplicatedStorage/` | ReplicatedStorage | Shared modules (Config, Signal) used by server and client |
| `ServerStorage/` | ServerStorage | Server-only modules (core clock, temperature, hunger, survival) |
| `ServerScript/` | ServerScriptService | Server scripts (runtime entry points — later step) |
| `PlayerScripts/` | StarterPlayer > StarterPlayerScripts | Client scripts (HUD, input — later phases) |
| `Others/` | not synced | Models, meshes, and other raw assets |

`default.project.json` is a Rojo project file that maps these folders into the tree above. Copy-pasting the folders into Studio by hand works too.

## Architecture rules

- **One clock per server.** `DayNightClock` and `Temperature` are singletons — the server script creates exactly one of each and every player's `SurvivalPlayer` shares them. Day, night, day count, multiplier and weather are identical for everyone; per-player clocks would desync the yeti, storms and night events.
- **Only bodies are per-player.** Health, warmth, hunger and sickness live in `SurvivalPlayer`, one instance per player.

## Status

**Phase 1 — Core clock (modules only).** No server or client scripts yet; the modules below are pure logic, driven by `:Update(dt)` calls a future server script will make every frame/tick.

- `DayNightClock` — day/night cycle (3 min day, 2 min night), day counter, day multiplier.
- `Temperature` — weather (Clear / Storm / Blizzard), ambient temperature, cold exposure rates.
- `Hunger` — hunger value, drain (sprinting drains 2x), starving state.
- `SurvivalPlayer` — one player's health / warmth / hunger / sickness, ticked together.
- `Config` — every tuning number in one place, including the animation ID table.
- `Signal` — tiny event helper the modules use instead of BindableEvents.
