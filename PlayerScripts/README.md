# PlayerScripts

Maps to **StarterPlayer > StarterPlayerScripts** in Studio.

- `SurvivalClient.client.lua` — builds the HUD in code (no manual GUI work): day / phase / temperature / multiplier / wood / campfire fuel / seed panel and Health-Warmth-Hunger bars, all in the game palette (aubergine `#3A0F34`, ice silver `#DDE3E7`, marigold `#EAA000`). Reads state from attributes the server sets — no polling remotes for display. Also handles sprint: hold the on-screen SPRINT button (touch) or Left Shift, which fires `Remotes/SetSprinting` to the server.
