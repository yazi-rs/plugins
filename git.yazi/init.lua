local WIN = ya.target_family() == "windows"
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
		local path
		if signs:find(p[1]) then
			path = line:sub(4, 4) == '"' and line:sub(5, -2) or line:sub(4)
			path = WIN and path:gsub("/", "\\") or path
		end
		if not path then
		elseif path:find("[/\\]$") then
			return p[2] == 3 and 30 or p[2], path:sub(1, -2)
		else
			return p[2], path
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

local function bubble_up(changed)
	local new, empty = {}, Url("")
	for k, v in pairs(changed) do
		if v ~= 3 and v ~= 30 then
			local url = Url(k):parent()
			while url and url ~= empty do
				local s = tostring(url)
				new[s] = (new[s] or 0) > v and new[s] or v
				url = url:parent()
			end
		end
	end
	return new
end

local function propagate_down(ignored, cwd, repo)
	local new, rel = {}, cwd:strip_prefix(repo)
	for k, v in pairs(ignored) do
		if v == 30 then
			if rel:starts_with(k) then
				new[tostring(repo:join(rel))] = 30
			elseif cwd == repo:join(k):parent() then
				new[k] = 3
			end
		end
	end
	return new
end

local add = ya.sync(function(st, cwd, repo, changed)
	st.dirs[cwd] = repo
	st.repos[repo] = st.repos[repo] or {}
	for k, v in pairs(changed) do
		if v == 0 then
			st.repos[repo][k] = nil
		elseif v == 30 then
			st.dirs[k] = ""
		else
			st.repos[repo][k] = v
		end
	end
	ya.render()
end)

local remove = ya.sync(function(st, cwd)
	local dir = st.dirs[cwd]
	if not dir then
		return
	end

	ya.render()
	st.dirs[cwd] = nil
	if not st.repos[dir] then
		return
	end

	for _, r in pairs(st.dirs) do
		if r == dir then
			return
		end
	end
	st.repos[dir] = nil
end)

local function setup(st, opts)
	st.dirs = {}
	st.repos = {}

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
		[3] = THEME.git_ignored and THEME.git_ignored.icon or "!",
		[2] = THEME.git_deleted and THEME.git_deleted.icon or "-",
		[1] = THEME.git_updated and THEME.git_updated.icon or "U",
	}

	Linemode:children_add(function(self)
		local url = self._file.url
		local dir = st.dirs[tostring(url:parent())]
		local change
		if dir then
			change = dir == "" and 3 or st.repos[dir][tostring(url):sub(#dir + 2)]
		end

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

	-- stylua: ignore
	local output, err = Command("git")
		:cwd(tostring(cwd))
		:args({ "--no-optional-locks", "-c", "core.quotePath=", "status", "--porcelain", "-unormal", "--no-renames", "--ignored=matching" })
		:args(paths)
		:stdout(Command.PIPED)
		:output()
	if not output then
		ya.err("Cannot spawn git command, error code " .. tostring(err))
		return 0
	end

	local changed, ignored = {}, {}
	for line in output.stdout:gmatch("[^\r\n]+") do
		local sign, path = match(line)
		if sign == 30 then
			ignored[path] = sign
		else
			changed[path] = sign
		end
	end

	if self.files[1].cha.is_dir then
		ya.dict_merge(changed, bubble_up(changed))
		ya.dict_merge(changed, propagate_down(ignored, cwd, Url(repo)))
	else
		ya.dict_merge(changed, propagate_down(ignored, cwd, Url(repo)))
	end

	for _, p in ipairs(paths) do
		local s = p:sub(#repo + 2)
		changed[s] = changed[s] or 0
	end
	add(tostring(cwd), repo, changed)

	return 3
end

return { setup = setup, fetch = fetch }
