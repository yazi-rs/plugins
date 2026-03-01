--- @since 25.12.29

local state = { auto_enter = true, confirm_keys = {} }

local function setup(_, opts)
	if opts.auto_enter ~= nil then
		state.auto_enter = opts.auto_enter
	end
	state.confirm_keys = opts.confirm_keys or {}
end

local hovered = ya.sync(function()
	local h = cx.active.current.hovered
	if not h then
		return {}
	end

	return {
		url = h.url,
		is_dir = h.cha.is_dir,
		unique = #cx.active.current.files == 1,
	}
end)

local function prompt()
	return ya.input {
		title = "Smart filter:",
		pos = { "center", w = 50 },
		realtime = true,
		debounce = 0.1,
	}
end

local function entry()
	local input = prompt()

	while true do
		local value, event = input:recv()
		if event ~= 1 and event ~= 3 then
			ya.emit("escape", { filter = true })
			break
		end

		local confirmed = event == 1
		if not confirmed then
			local last = value:sub(-1)
			for _, key in ipairs(state.confirm_keys) do
				if last == key then
					confirmed = true
					value = value:sub(1, -2)
					break
				end
			end
		end

		ya.emit("filter_do", { value, smart = true })

		local h = hovered()
		if state.auto_enter and not confirmed and h.unique and h.is_dir then
			ya.emit("escape", { filter = true })
			ya.emit("enter", {})
			input = prompt()
		elseif confirmed then
			ya.emit("escape", { filter = true })
			ya.emit(h.is_dir and "enter" or "open", { h.url })
			if h.is_dir then
				input = prompt()
			else
				break
			end
		end
	end
end

return { entry = entry, setup = setup }
