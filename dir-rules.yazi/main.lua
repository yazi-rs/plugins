--- @since 25.5.28

local prev_pref = {}

local function setup(st, opts)
	st.rules = opts.rules or {}
	
	ps.sub("cd", function()
		local cwd = cx.active.current.cwd
		local prefs = cx.active.pref

		local cur_pref = {
			sort = {
				prefs.sort_by,
				sensitive = prefs.sort_sensitive,
				reverse = prefs.sort_reverse,
				dir_first = prefs.sort_dir_first,
				translit = prefs.sort_translit,
			},
			linemode = { prefs.linemode },
		}
		if prefs.show_hidden then
			cur_pref.hidden = { "show" }
		else
			cur_pref.hidden = { "hide" }
		end

		local save_pref = false

		for dir, dir_pref in pairs(st.rules) do
			if cwd:ends_with(dir) then
				for k, v in pairs(dir_pref) do
					ya.emit(k, v)
				end
				save_pref = true
				break
			end
		end

		if save_pref then
			prev_pref = cur_pref
		else
			for k, v in pairs(prev_pref) do
				ya.emit(k, v)
			end
		end
	end)
end

return { setup = setup }
