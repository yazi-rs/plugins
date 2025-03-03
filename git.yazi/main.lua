--- @since 25.2.7

---@alias StatusStr "ignored" | "untracked" | "added" | "modified" | "deleted" | "updated"
---@alias FullPath string
---@alias RelativePath string
---@alias Changes table<RelativePath, Status>

---@class Config
---@field order number
---@field styles table<Status, ui.Style>
---@field icons table<Status, string>

---@class PluginState
---@field dirs_to_repo table<FullPath, FullPath> stores the mapping from directories to repositories
---@field repos table<FullPath, Changes> stores the changes of each repository

---@class SetupOptions
---@field order? number The order of the git linemode to display

---@class ThemeOptions
---@field [string] ui.Style|table|string

---@enum Status
local Status = {
	ignored = 6,
	untracked = 5,
	added = 4,
	modified = 3,
	deleted = 2,
	updated = 1,
	unkonwn = 0,
}

---@type table<string, Status>
local PATTERNS = {
	{ "!$", Status.ignored },
	{ "?$", Status.untracked },
	{ "[AC]", Status.added },
	{ "[MT]", Status.modified },
	{ "D", Status.deleted },
	{ "U", Status.updated },
	{ "[AD][AD]", Status.updated },
}

---@type Config
local Config = {
	order = 1500,
	styles = {
		[Status.ignored] = ui.Style():fg("darkgray"),
		[Status.untracked] = ui.Style():fg("magenta"),
		[Status.added] = ui.Style():fg("green"),
		[Status.modified] = ui.Style():fg("yellow"),
		[Status.deleted] = ui.Style():fg("red"),
		[Status.updated] = ui.Style():fg("yellow"),
	},
	icons = {
		[Status.ignored] = "",
		[Status.untracked] = "?",
		[Status.added] = "",
		[Status.modified] = "",
		[Status.deleted] = "",
		[Status.updated] = "",
	},
}

local is_windows = ya.target_family() == "windows"

---@param line string
---@return Status?, RelativePath?
local function match(line)
	local sign = line:sub(1, 2)
	for _, p in ipairs(PATTERNS) do
		local pattern, status = p[1], p[2]
		local path
		if sign:find(pattern) then
			path = line:sub(4, 4) == '"' and line:sub(5, -2) or line:sub(4)
			path = is_windows and path:gsub("/", "\\") or path
		end
		if path then
			return status, path:find("[/\\]$") and path:sub(1, -2) or path
		end
	end
end

---@param url Url
---@return boolean
local function is_worktree(url)
	local file, head = io.open(tostring(url)), nil
	if file then
		head = file:read(8)
		file:close()
	end
	return head == "gitdir: "
end

---@param cwd FullPath
---@return FullPath?
local function root(cwd)
	cwd = Url(cwd)
	repeat
		local next = cwd:join(".git")
		local cha = fs.cha(next)
		if cha and (cha.is_dir or is_worktree(next)) then
			return tostring(cwd)
		end
		cwd = cwd:parent()
	until not cwd
end

---@param changes Changes
---@return Changes
local function bubble_up(changes)
	local new, empty = {}, Url("")
	for path, status in pairs(changes) do
		if status ~= Status.ignored then
			local url = Url(path):parent()
			while url and url ~= empty do
				local s = tostring(url)
				new[s] = (new[s] or Status.unkonwn) > status and new[s] or status
				url = url:parent()
			end
		end
	end
	return new
end

---@param st PluginState
---@param cwd FullPath
---@param repo FullPath
---@param changes Changes
local add = ya.sync(function(st, cwd, repo, changes)
	st.dirs_to_repo[cwd] = repo
	st.repos[repo] = st.repos[repo] or {}
	for path, status in pairs(changes) do
		st.repos[repo][path] = status
	end
	ya.render()
end)

---@param st PluginState
---@param cwd FullPath
local remove = ya.sync(function(st, cwd)
	local dir = st.dirs_to_repo[cwd]
	if not dir then
		return
	end

	ya.render()
	st.dirs_to_repo[cwd] = nil
	if not st.repos[dir] then
		return
	end

	for _, r in pairs(st.dirs_to_repo) do
		if r == dir then
			return
		end
	end
	st.repos[dir] = nil
end)

---@param options SetupOptions
local function merge_options(options)
	if options.order ~= nil then
		Config.order = options.order
	end
end

---@param options ThemeOptions
local function merge_theme_options(options)
	for k, v in pairs(options) do
		if k:find("_sign$") then
			Config.icons[Status[k:sub(1, -6)]] = v
		else
			Config.styles[Status[k]] = ui.Style(v)
		end
	end
end

---@param st PluginState
---@param opts? SetupOptions
local function setup(st, opts)
	st.dirs_to_repo = {}
	st.repos = {}

	merge_options(opts or {})
	merge_theme_options(THEME.git or {})

	---@param self { _file: File }
	---@return Status?
	local function get_status(self)
		local url = self._file.url
		local repo = st.dirs_to_repo[tostring(url:parent())]
		if repo then
			local ret = st.repos[repo][tostring(url):sub(#repo + 2)]
			if not ret then
				local path = url:parent()
				local repo_url = Url(repo)
				while path and path ~= repo_url do
					if st.repos[repo][tostring(path):sub(#repo + 2)] == Status.ignored then
						st.repos[repo][tostring(url):sub(#repo + 2)] = Status.ignored
						return Status.ignored
					end
					path = path:parent()
				end
			else
				return ret
			end
		end
	end

	Linemode:children_add(function(self)
		local status = get_status(self)
		if not status or Config.icons[status] == "" then
			return ""
		elseif self._file:is_hovered() then
			return ui.Line { " ", Config.icons[status] }
		else
			return ui.Line { " ", ui.Span(Config.icons[status]):style(Config.styles[status]) }
		end
	end, Config.order)
end

---@param _ PluginState
---@param job { files: File[] }
local function fetch(_, job)
	local cwd = tostring(job.files[1].url:parent()) ---@type FullPath
	local repo = root(cwd) ---@type FullPath?
	if not repo then
		remove(cwd)
		return true
	end

	local paths = {}
	for _, f in ipairs(job.files) do
		paths[#paths + 1] = tostring(f.url)
	end

	local output, err = Command("git")
		:cwd(cwd)
		:args({
			"--no-optional-locks",
			"-c",
			"core.quotePath=",
			"status",
			"--porcelain",
			"-unormal",
			"--no-renames",
			"--ignored=matching",
		})
		:args(paths)
		:stdout(Command.PIPED)
		:output()
	if not output then
		return true, Err("Cannot spawn `git` command, error: %s", err)
	end

	local changes = {}
	for line in output.stdout:gmatch("[^\r\n]+") do
		local status, path = match(line)
		if status and path then
			changes[path] = status
		end
	end

	ya.dict_merge(changes, bubble_up(changes))

	add(cwd, repo, changes)

	return false
end

return { setup = setup, fetch = fetch }
