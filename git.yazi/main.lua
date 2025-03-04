--- @since 25.2.7

local WINDOWS = ya.target_family() == "windows"
local CODES = {
	modified = 6,
	added = 5,
	untracked = 4,
	ignored = 3, -- ignored file
	excluded = 30, -- ignored directory
	deleted = 2,
	updated = 1,
	unknown = 0,
}
local PATTERNS = {
	{ "[MT]", CODES.modified },
	{ "[AC]", CODES.added },
	{ "?$", CODES.untracked },
	{ "!$", CODES.ignored },
	{ "D", CODES.deleted },
	{ "U", CODES.updated },
	{ "[AD][AD]", CODES.updated },
}

local function match(line)
	local signs = line:sub(1, 2)
	for _, p in ipairs(PATTERNS) do
		local path
		if signs:find(p[1]) then
			path = line:sub(4, 4) == '"' and line:sub(5, -2) or line:sub(4)
			path = WINDOWS and path:gsub("/", "\\") or path
		end
		if not path then
		elseif path:find("[/\\]$") then
			return p[2] == CODES.ignored and CODES.excluded or p[2], path:sub(1, -2)
		else
			return p[2], path
		end
	end
end

local function root(cwd)
	local is_worktree = function(url)
		local file, head = io.open(tostring(url)), nil
		if file then
			head = file:read(8)
			file:close()
		end
		return head == "gitdir: "
	end

	repeat
		local next = cwd:join(".git")
		local cha = fs.cha(next)
		if cha and (cha.is_dir or is_worktree(next)) then
			return tostring(cwd)
		end
		cwd = cwd:parent()
	until not cwd
end

local function bubble_up(changed)
	local new, empty = {}, Url("")
	for k, v in pairs(changed) do
		if v ~= CODES.ignored and v ~= CODES.excluded then
			local url = Url(k):parent()
			while url and url ~= empty do
				local s = tostring(url)
				new[s] = (new[s] or CODES.unknown) > v and new[s] or v
				url = url:parent()
			end
		end
	end
	return new
end

local function propagate_down(ignored, cwd, repo)
	local new, rel = {}, cwd:strip_prefix(repo)
	for k, v in pairs(ignored) do
		if v == CODES.excluded then
			if rel:starts_with(k) then
				new[tostring(repo:join(rel))] = CODES.excluded
			elseif cwd == repo:join(k):parent() then
				new[k] = CODES.ignored
			end
		end
	end
	return new
end

local add = ya.sync(function(st, cwd, repo, changed)
	st.dirs[cwd] = repo
	st.repos[repo] = st.repos[repo] or {}
	for k, v in pairs(changed) do
		if v == CODES.unknown then
			st.repos[repo][k] = nil
		elseif v == CODES.excluded then
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
	opts.order = opts.order or 1500

	-- Chosen by ChatGPT fairly, PRs are welcome to adjust them
	local t = THEME.git or {}
	local styles = {
		[CODES.modified] = t.modified and ui.Style(t.modified) or ui.Style():fg("#ffa500"),
		[CODES.added] = t.added and ui.Style(t.added) or ui.Style():fg("#32cd32"),
		[CODES.untracked] = t.untracked and ui.Style(t.untracked) or ui.Style():fg("#a9a9a9"),
		[CODES.ignored] = t.ignored and ui.Style(t.ignored) or ui.Style():fg("#696969"),
		[CODES.deleted] = t.deleted and ui.Style(t.deleted) or ui.Style():fg("#ff4500"),
		[CODES.updated] = t.updated and ui.Style(t.updated) or ui.Style():fg("#1e90ff"),
	}
	local signs = {
		[CODES.modified] = t.modified_sign or "",
		[CODES.added] = t.added_sign or "",
		[CODES.untracked] = t.untracked_sign or "",
		[CODES.ignored] = t.ignored_sign or "",
		[CODES.deleted] = t.deleted_sign or "",
		[CODES.updated] = t.updated_sign or "U",
	}

	Linemode:children_add(function(self)
		local url = self._file.url
		local dir = st.dirs[tostring(url:parent())]
		local change
		if dir then
			change = dir == "" and CODES.ignored or st.repos[dir][tostring(url):sub(#dir + 2)]
		end

		if not change or signs[change] == "" then
			return ""
		elseif self._file:is_hovered() then
			return ui.Line { " ", signs[change] }
		else
			return ui.Line { " ", ui.Span(signs[change]):style(styles[change]) }
		end
	end, opts.order)
end

local function fetch(_, job)
	local cwd = job.files[1].url:parent()
	local repo = root(cwd)
	if not repo then
		remove(tostring(cwd))
		return true
	end

	local paths = {}
	for _, f in ipairs(job.files) do
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
		return true, Err("Cannot spawn `git` command, error: %s", err)
	end

	local changed, ignored = {}, {}
	for line in output.stdout:gmatch("[^\r\n]+") do
		local sign, path = match(line)
		if sign == CODES.excluded then
			ignored[path] = sign
		else
			changed[path] = sign
		end
	end

	if job.files[1].cha.is_dir then
		ya.dict_merge(changed, bubble_up(changed))
		ya.dict_merge(changed, propagate_down(ignored, cwd, Url(repo)))
	else
		ya.dict_merge(changed, propagate_down(ignored, cwd, Url(repo)))
	end

	for _, p in ipairs(paths) do
		local s = p:sub(#repo + 2)
		changed[s] = changed[s] or CODES.unknown
	end
	add(tostring(cwd), repo, changed)

	return false
end

return { setup = setup, fetch = fetch }
