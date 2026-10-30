-- Parallel: a safe, small Parallel Luau wrapper.
--
-- True Parallel Luau needs an Actor: a script running
-- under an Actor can call task.desynchronize() and do
-- work on another core, then task.synchronize() to
-- touch the game again. Without an Actor, calling
-- desynchronize does nothing useful -- so this module
-- never pretends. It has two modes:
--
-- 1. Parallel.RunChunked(list, fn, budget): the safe
--    workhorse for today. It processes a list in
--    small chunks with task.wait() between them, so
--    24 wolves, 400 trees, or 420 grass tufts never
--    freeze one frame. This is staggered work, not
--    multi-core -- it is honest about that.
--
-- 2. Parallel.Desync(fn): only does real multi-core
--    work when called from inside an Actor script.
--    Anywhere else it just runs fn normally. Use it
--    for pure math only (no Instance access, no
--    game state) -- e.g. terrain height sampling or
--    sorting wolf distances -- and return the result
--    to the main thread before touching the game.
--
-- Next step when you want real cores: put a Script
-- under an Actor in Studio, require this module
-- there, and call Parallel.Desync for the wolf
-- distance sort. Do NOT move wolf state or damage
-- into parallel code -- parallel code cannot safely
-- write game state, only compute and return.
local Parallel = {}

function Parallel.RunChunked(list, fn, chunkSize)
	chunkSize = chunkSize or 8
	for i = 1, #list, chunkSize do
		for j = i, math.min(i + chunkSize - 1, #list) do
			fn(list[j], j)
		end
		if i + chunkSize <= #list then
			task.wait()
		end
	end
end

function Parallel.Desync(fn, ...)
	if task.desynchronize then
		-- Only meaningful under an Actor; outside one
		-- this is a normal call, which is safe.
		local ok, result = pcall(function(...)
			task.desynchronize()
			local value = fn(...)
			task.synchronize()
			return value
		end, ...)
		if ok then
			return result
		end
	end
	return fn(...)
end

return Parallel
