--- @since 25.5.31

local AVAILABLE_CHARS = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789."

local changed = ya.sync(function(st, new)
	local b = st.last ~= new
	st.last = new
	return b or not cx.active.finder
end)

local escape = function(s) return s == "." and "\\." or s end

return {
	entry = function(self, job)
		local cands = {}
		for i = 1, #AVAILABLE_CHARS do
			cands[#cands + 1] = { on = AVAILABLE_CHARS:sub(i, i) }
		end

		local idx = ya.which { cands = cands, silent = true }
		if not idx then
			return
		end

		local kw = escape(cands[idx].on)
		if changed(kw) then
			if job.args.ignorecase and kw:match("%a") then
				ya.emit("find_do", { "^(" .. kw:lower() .. "|" .. kw:upper() .. ")" })
			elseif job.args.smartcase and kw:match("^%l$") then
				ya.emit("find_do", { "^(" .. kw .. "|" .. kw:upper() .. ")" })
			else
				ya.emit("find_do", { "^" .. kw })
			end
		else
			ya.emit("find_arrow", {})
		end
	end,
}
