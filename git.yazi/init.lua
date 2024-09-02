local PATS = {
	{ "[MT]", "M" }, -- Modified
	{ "[AC]", "A" }, -- Added
	{ "?$", "?" }, -- Untracked
	{ "D", "D" }, -- Deleted
	{ "U", "U" }, -- Updated
	{ "[AD][AD]", "U" }, -- Updated
}

local WEIGHTS = {
	["M"] = 6,
	["A"] = 5,
	["?"] = 4,
	["D"] = 3,
	["U"] = 2,
	[""] = 1,
}

local function match(line)
	local signs = line:sub(1, 2)
	for _, p in ipairs(PATS) do
		if not signs:find(p[1]) then
		elseif line:sub(4, 4) == '"' then
			return p[2], line:sub(5, -2)
		else
			return p[2], line:sub(4)
		end
	end
end

local function root(cwd)
	repeat
		local cha = fs.cha(cwd:join(".git"))
		if cha and cha.is_dir then
			return string.format("%s%s", cwd, ya.target_family() == "windows" and "\\" or "/")
		end
		cwd = cwd:parent()
	until not cwd
end

local save = ya.sync(function(st, states)
	st.states = st.states or {}
	for k, v in pairs(states) do
		st.states[k] = v ~= "" and v or nil
	end
	ya.render()
end)

local function setup(st, opts)
	st.states = {}
	opts = opts or {}
	opts.order = opts.order or 500

	local styles = {
		["M"] = THEME.git_modified and ui.Style(THEME.git_modified) or ui.Style():fg("blue"),
		["A"] = THEME.git_added and ui.Style(THEME.git_added) or ui.Style():fg("green"),
		["?"] = THEME.git_untracked and ui.Style(THEME.git_untracked) or ui.Style():fg("yellow"),
		["D"] = THEME.git_deleted and ui.Style(THEME.git_deleted) or ui.Style():fg("red"),
		["U"] = THEME.git_updated and ui.Style(THEME.git_updated) or ui.Style():fg("blue"),
	}
	local icons = {
		["M"] = THEME.git_modified and THEME.git_modified.icon or "M",
		["A"] = THEME.git_added and THEME.git_added.icon or "A",
		["?"] = THEME.git_untracked and THEME.git_untracked.icon or "?",
		["D"] = THEME.git_deleted and THEME.git_deleted.icon or "D",
		["U"] = THEME.git_updated and THEME.git_updated.icon or "U",
	}

	Linemode:children_add(function(self)
		local s = st.states[tostring(self._file.url)]
		if s and icons[s] ~= "" then
			return ui.Line { ui.Span(" "), ui.Span(icons[s]):style(styles[s]) }
		else
			return ui.Line {}
		end
	end, opts.order)
end

local function fetch(self)
	local paths = {}
	for _, file in ipairs(self.files) do
		paths[#paths + 1] = tostring(file.url)
	end

	local cwd = self.files[1].url:parent()
	local output, err = Command("git")
		:cwd(tostring(cwd))
		:args({ "-c", "core.quotePath=", "status", "--porcelain", "-unormal", "--no-renames" })
		:args(paths)
		:stdout(Command.PIPED)
		:output()
	if not output then
		ya.err("Cannot spawn git command, error code " .. tostring(err))
		return 0
	end

	local prefix = root(cwd)
	if not prefix then
		return 1
	end

	local states = {}
	for line in output.stdout:gmatch("[^\r\n]+") do
		local sign, path = match(line)
		if not sign then
		elseif path:find("[/\\]$") then
			states[prefix .. path:sub(1, -2)] = sign
		else
			states[prefix .. path] = sign
		end
	end

	prefix = Url(prefix)
	if self.files[1].cha.is_dir then
		local parents = {}
		for k, v in pairs(states) do
			local url = Url(k):parent()
			while url and url ~= prefix do
				local s = tostring(url)
				parents[s] = (WEIGHTS[parents[s]] or 0) > WEIGHTS[v] and parents[s] or v
				url = url:parent()
			end
		end
		for k, v in pairs(parents) do
			states[k] = v
		end
	end

	for _, p in ipairs(paths) do
		states[p] = states[p] or ""
	end
	save(states)

	return 3
end

return { setup = setup, fetch = fetch }
