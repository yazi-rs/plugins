--- @since 25.5.31

local WINDOWS = ya.target_family() == "windows"

---@enum DiffType
local DiffType = {
	conflicted = 6,
	modified = 5,
	added = 4,
	deleted = 3,
	updated = 2,
	renamed = 1,
	unknown = 0,
}

local function end_fetch_(err)
	if not err then
		return true
	end
	return false, err
end

---@param line string
---@return DiffType?, string?
local function parse_diff_summary(line)
	-- JJ summary lines: "A path", "M path", "D path", "R {old => new}"
	local kind, rest = line:match("^(%u) (.+)$")
	if not kind or not rest then
		return nil, nil
	end

	local path = rest
	if kind == "R" then
	  local new = rest
	    :gsub("%{%s*(.-)%s*=>%s*(.-)%s*%}", "%2", 1)  -- Handles: {file.txt => inner/file.txt}
	    :gsub("/+", "/")                              -- collapse accidental `//` to handle src/{inner => }/file.txt
	  																								-- and {src => inner/src}/path/file.txt
	  if new and #new > 0 then
	    path = new
	  end
	end

	if WINDOWS then
		path = path:gsub("/", "\\")
	end

	if kind == "A" then
		return DiffType.added, path
	elseif kind == "M" then
		return DiffType.modified, path
	elseif kind == "D" then
		return DiffType.deleted, path
	elseif kind == "R" then
		return DiffType.renamed, path
	end
	return nil, nil
end

---@param cwd_url Url
---@return string?
local function jj_root(cwd_url)
	repeat
		local jj = cwd_url:join(".jj")
		local cha = fs.cha(jj)
		if cha and cha.is_dir then
			return tostring(cwd_url)
		end
		cwd_url = cwd_url.parent
	until not cwd_url
end

---@param changed table<string, DiffType>
---@return table<string, DiffType>
local function bubble_up(changed)
	local dirs = {}
	local empty = Url("")

	-- collect descendant statuses per directory
	for path, code in pairs(changed) do
		local url = Url(path).parent
		while url and url ~= empty do
			local s = tostring(url)
			local st = dirs[s]
			if not st then
				st = { seen = {}, has_conflict = false }
				dirs[s] = st
			end
			st.seen[code] = true
			if code == DiffType.conflicted then
				st.has_conflict = true
			end
			url = url.parent
		end
	end

	-- decide directory badge
	local out = {}
	for dir, st in pairs(dirs) do
		if st.has_conflict then
			out[dir] = DiffType.conflicted
		else
			local count, last = 0, nil
			for code, _ in pairs(st.seen) do
				count = count + 1
				last = code
			end
			if count <= 1 then
				out[dir] = last or DiffType.unknown
			else
				out[dir] = DiffType.modified
			end
		end
	end
	return out
end

---@param repo string
---@param paths string[]
---@return table<string, DiffType>|nil, string?
local function run_jj_diff_summary(repo, paths)
	local out, err =
		Command("jj"):cwd(repo):arg({ "diff", "--summary", "-r", "@" }):arg(paths):stdout(Command.PIPED):output()
	if err then
		return nil, ("Cannot spawn `jj diff`, stderr output: %s"):format(err)
	end
	if not out then
		return nil
	end

	local changed = {}
	for line in out.stdout:gmatch("[^\r\n]+") do
		local code, path = parse_diff_summary(line)
		if code and path then
			changed[path] = code
		end
	end
	return changed, nil
end

---@param repo string
---@return table<string, true>|nil, string?
local function run_jj_conflicts(repo)
	-- `jj resolve --list -r @` prints paths that have conflicts
	local out, err = Command("jj"):cwd(repo):arg({ "resolve", "--list", "-r", "@" }):stdout(Command.PIPED):output()
	if err then
		return nil, ("Cannot spawn `jj resolve`, stderr output: %s"):format(err)
	end

	local conflicts = {}
	for line in out.stdout:gmatch("[^\r\n]+") do
		local path = line:match("^(.-)%s+.+$") or line:match("^(.+)$")
		if path and #path > 0 then
			if WINDOWS then
				path = path:gsub("/", "\\")
			end
			conflicts[path] = true
		end
	end
	return conflicts, nil
end

-- ==========================================

---@param cwd string
---@param repo string
---@param changed table<string, DiffType>
local add = ya.sync(function(st, cwd, repo, changed)
	---@cast st State
	st.dirs[cwd] = repo
	st.repos[repo] = st.repos[repo] or {}
	for path, code in pairs(changed) do
		if code == DiffType.unknown then
			st.repos[repo][path] = nil
		elseif code == DiffType.excluded then
			st.dirs[path] = DiffType.excluded
		else
			st.repos[repo][path] = code
		end
	end
	ya.render()
end)

---@param cwd string
local remove = ya.sync(function(st, cwd)
	---@cast st State
	local repo = st.dirs[cwd]
	if not repo then
		return
	end

	ya.render()
	st.dirs[cwd] = nil
	if not st.repos[repo] then
		return
	end

	for _, r in pairs(st.dirs) do
		if r == repo then
			return
		end
	end
	st.repos[repo] = nil
end)

---@param st State
---@param opts Options
local function setup(st, opts)
	st.dirs = {}
	st.repos = {}

	opts = opts or {}
	opts.order = opts.order or 1500

	local t = th.jj or {}
	local styles = {}
	styles[DiffType.conflicted] = t.conflicted and ui.Style(t.conflicted) or ui.Style():fg("red"):bold(true)
	styles[DiffType.renamed] = t.renamed and ui.Style(t.renamed) or ui.Style():fg("cyan")
	styles[DiffType.modified] = t.modified and ui.Style(t.modified) or ui.Style():fg("yellow")
	styles[DiffType.added] = t.added and ui.Style(t.added) or ui.Style():fg("green")
	styles[DiffType.deleted] = t.deleted and ui.Style(t.deleted) or ui.Style():fg("red")
	styles[DiffType.updated] = t.updated and ui.Style(t.updated) or ui.Style():fg("yellow")

	local signs = {
		[DiffType.conflicted] = t.conflicted_sign or "🞩",
		[DiffType.renamed] = t.renamed_sign or "",
		[DiffType.modified] = t.modified_sign or "",
		[DiffType.added] = t.added_sign or "",
		[DiffType.deleted] = t.deleted_sign or "",
		[DiffType.updated] = t.updated_sign or "",
	}

	Linemode:children_add(function(self)
		local url = self._file.url
		local repo = st.dirs[tostring(url.base)]
		local code
		if repo then
			local rel = tostring(url):sub(#repo + 2)
			code = st.repos[repo][rel]
		end

		if not code or signs[code] == "" then
			return ""
		elseif self._file.is_hovered then
			return ui.Line { " ", signs[code] }
		else
			return ui.Line { " ", ui.Span(signs[code]):style(styles[code]) }
		end
	end, opts.order)
end

---@type UnstableFetcher
local function fetch(_, job)
	local cwd_url = job.files[1].url
	local cwd = cwd_url.base
	local repo = jj_root(cwd_url)
	if not repo then
		remove(tostring(cwd))
		return end_fetch_(Err("Not a jj repository"))
	end

	local paths, rels = {}, {}
	local repo_len = #repo
	for _, file in ipairs(job.files) do
		local p = tostring(file.url)
		paths[#paths + 1] = p
		rels[p] = p:sub(repo_len + 2)
	end

	-- 1) diff summary
	local changed, diff_err = run_jj_diff_summary(repo, paths)
	if diff_err then
		return end_fetch_(Err("%s", diff_err))
	end
	changed = changed or {}

	-- 2) conflicts (override any diff status for the same path)
	local conflicts, conf_err = run_jj_conflicts(repo)
	if conf_err then
		return end_fetch_(Err("%s", conf_err))
	end
	if conflicts then
		for path, _ in pairs(conflicts) do
			changed[path] = DiffType.conflicted
		end
	end

	if job.files[1].cha.is_dir then
		ya.dict_merge(changed, bubble_up(changed))
		ya.dbg(changed)
	end

	for abs, rel in pairs(rels) do
		changed[rel] = changed[rel] or DiffType.unknown
	end

	add(tostring(cwd), repo, changed)
	return false
end

return { setup = setup, fetch = fetch }
