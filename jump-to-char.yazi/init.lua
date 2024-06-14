local AVAILABLE_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"

local changed = ya.sync(function(st, new)
	local b = st.last ~= new
	st.last = new
	return b
end)

return {
	entry = function()
		local cands = {}
		for i = 1, #AVAILABLE_CHARS do
			cands[#cands + 1] = { on = AVAILABLE_CHARS:sub(i, i) }
		end

		local idx = ya.which { cands = cands, silent = true }
		if not idx then
			return
		end

		if changed(cands[idx].on) then
			ya.manager_emit("find_do", { insensitive = true, "^" .. cands[idx].on })
		else
			ya.manager_emit("find_arrow", {})
		end
	end,
}
