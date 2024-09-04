local PATS = {
	{ "[MT]", 6 }, -- Modified
	{ "[AC]", 5 }, -- Added
	{ "?$", 4 }, -- Untracked
	{ "!$", 3 }, -- Ignored
	{ "D", 2 }, -- Deleted
	{ "U", 1 }, -- Updated
	{ "[AD][AD]", 1 }, -- Updated
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
			return tostring(cwd)
		end
		cwd = cwd:parent()
	until not cwd
end

local add = ya.sync(function(st, cwd, repo, changes)
	st.repos[cwd] = repo
	st.changes[repo] = st.changes[repo] or {}
	for k, v in pairs(changes) do
		st.changes[repo][k] = v ~= 0 and v or nil
	end
	ya.render()
end)

local remove = ya.sync(function(st, cwd)
	local repo = st.repos[cwd]
	if not repo then
		return
	end

	ya.render()
	st.repos[cwd] = nil
	if not st.changes[repo] then
		return
	end

	for _, r in pairs(st.repos) do
		if r == repo then
			return
		end
	end
	st.changes[repo] = nil
end)

local function setup(st, opts)
	st.repos = {}
	st.changes = {}

	opts = opts or {}
	opts.order = opts.order or 500

	-- Chosen by ChatGPT fairly, PRs are welcome to adjust them
	local styles = {
		[6] = THEME.git_modified and ui.Style(THEME.git_modified) or ui.Style():fg("#ffa500"),
		[5] = THEME.git_added and ui.Style(THEME.git_added) or ui.Style():fg("#32cd32"),
		[4] = THEME.git_untracked and ui.Style(THEME.git_untracked) or ui.Style():fg("#a9a9a9"),
		[3] = THEME.git_ignored and ui.Style(THEME.git_ignored) or ui.Style():fg("#696969"),
		[2] = THEME.git_deleted and ui.Style(THEME.git_deleted) or ui.Style():fg("#ff4500"),
		[1] = THEME.git_updated and ui.Style(THEME.git_updated) or ui.Style():fg("#1e90ff"),
	}
	-- TODO: Use nerd-font icons as default matching Yazi's default behavior
	local icons = {
		[6] = THEME.git_modified and THEME.git_modified.icon or "*",
		[5] = THEME.git_added and THEME.git_added.icon or "+",
		[4] = THEME.git_untracked and THEME.git_untracked.icon or "?",
		[3] = THEME.git_ignored and THEME.git_ignored.icon or "",
		[2] = THEME.git_deleted and THEME.git_deleted.icon or "-",
		[1] = THEME.git_updated and THEME.git_updated.icon or "U",
	}

	Linemode:children_add(function(self)
		local url = self._file.url
		local repo = st.repos[tostring(url:parent())]
		if not repo then
			return ui.Line("")
		end

		local change = st.changes[repo][tostring(url):sub(#repo + 2)]
		if not change or icons[change] == "" then
			return ui.Line("")
		elseif self._file:is_hovered() then
			return ui.Line { ui.Span(" "), ui.Span(icons[change]) }
		else
			return ui.Line { ui.Span(" "), ui.Span(icons[change]):style(styles[change]) }
		end
	end, opts.order)
end

local function fetch(self)
	local cwd = self.files[1].url:parent()
	local repo = root(cwd)
	if not repo then
		remove(tostring(cwd))
		return 1
	end

	local paths = {}
	for _, f in ipairs(self.files) do
		paths[#paths + 1] = tostring(f.url)
	end

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

	local changes = {}
	for line in output.stdout:gmatch("[^\r\n]+") do
		local sign, path = match(line)
		if not sign then
		elseif path:find("[/\\]$") then
			changes[path:sub(1, -2)] = sign
		else
			changes[path] = sign
		end
	end

	if self.files[1].cha.is_dir then
		local parents, empty_url = {}, Url("")
		for k, v in pairs(changes) do
			local url = Url(k):parent()
			while url and url ~= empty_url do
				local s = tostring(url)
				parents[s] = (parents[s] or 0) > v and parents[s] or v
				url = url:parent()
			end
		end
		for k, v in pairs(parents) do
			changes[k] = v
		end
	end

	for _, f in ipairs(self.files) do
		local name = f.url:name()
		changes[name] = changes[name] or 0
	end
	add(tostring(cwd), repo, changes)

	return 3
end

return { setup = setup, fetch = fetch }
