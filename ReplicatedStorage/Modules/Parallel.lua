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
