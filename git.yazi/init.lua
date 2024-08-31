local PATS = {
	{ "!$", "." }, -- Ignored
	{ "?$", "?" }, -- Untracked
	{ "U", "U" }, -- Updated
	{ "[AD][AD]", "U" }, -- Updated
	{ "[MT]", "M" }, -- Modified
	{ "[AC]", "A" }, -- Added
}

local PRIOS = {
	[""] = 1,
	["."] = 2,
	["?"] = 3,
	["U"] = 4,
	["M"] = 5,
	["A"] = 6,
}

local function match(s)
	for _, p in ipairs(PATS) do
		if s:find(p[1]) then
			return p[2]
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
	local styles = {
		["."] = THEME.git_ignored and ui.Style(THEME.git_ignored) or ui.Style():fg("gray"),
		["?"] = THEME.git_staged and ui.Style(THEME.git_staged) or ui.Style():fg("yellow"),
		["U"] = THEME.git_untracked and ui.Style(THEME.git_untracked) or ui.Style():fg("blue"),
		["M"] = THEME.git_modified and ui.Style(THEME.git_modified) or ui.Style():fg("red"),
		["A"] = THEME.git_deleted and ui.Style(THEME.git_deleted) or ui.Style():fg("green"),
	}

	Linemode:children_add(function(self)
		local state = st.states[tostring(self._file.url)]
		if state then
			return ui.Line { ui.Span(" "), ui.Span(state):style(styles[state]), ui.Span(" ") }
		else
			return ui.Line {}
		end
	end, opts.order or 5000)
end

local function fetch(self)
	local paths = {}
	for _, file in ipairs(self.files) do
		paths[#paths + 1] = tostring(file.url)
	end

	local cwd = self.files[1].url:parent()
	local output, err = Command("git")
		:cwd(tostring(cwd))
		:args({ "-c", "core.quotePath=", "status", "--porcelain", "-unormal", "--no-renames", "--ignored=matching" })
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
		local s = match(line:sub(1, 2))
		if s and line:find("[/\\]$") then
			states[prefix .. line:sub(4, -2)] = s
		else
			states[prefix .. line:sub(4)] = s
		end
	end

	prefix = Url(prefix)
	if self.files[1].cha.is_dir then
		local parents = {}
		for k, v in pairs(states) do
			local url = Url(k):parent()
			while url and url ~= prefix do
				local s = tostring(url)
				parents[s] = (PRIOS[parents[s]] or 0) > PRIOS[v] and parents[s] or v
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
