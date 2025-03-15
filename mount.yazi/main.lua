--- @since 25.2.26

local M = {
	keys = {
		{ on = "q",       run = "quit", },

		{ on = "k",       run = "up", },
		{ on = "j",       run = "down", },
		{ on = "l",       run = { "enter", "quit", }, },

		{ on = "<Up>",    run = "up", },
		{ on = "<Down>",  run = "down", },
		{ on = "<Right>", run = { "enter", "quit", }, },

		{ on = "m",       run = "mount", },
		{ on = "u",       run = "unmount", },
		{ on = "e",       run = "eject", },
	},
}

---@type fun(): string
local MUI_get_fstype = ya.sync(function(self)
	---@cast self PluginState
	return self.fstype or "*"
end)

---@type fun(fstype: string): nil
local MUI_set_fstype = ya.sync(function(self, fstype)
	---@cast self PluginState
	self.fstype = fstype
end)

---@type fun(): nil
local MUI_refresh = ya.sync(function(self)
	---@cast self PluginState
	ya.mgr_emit("plugin", { self._id, "__refresh", })
end)

---@type fun(): nil
local MUI_subscribe_to_mounts = ya.sync(function()
	ps.unsub("mount")
	ps.sub("mount", function()
		MUI_refresh()
	end)
end)

---@type fun(): MountDescription
local MUI_get_selected_entry = ya.sync(function(self)
	---@cast self PluginState
	return self.entries[self.cursor + 1]
end)

---@type fun(): nil
local MUI_toggle = ya.sync(function(self)
	---@cast self PluginState
	if self.children then
		Modal:children_remove(self.children)
		self.children = nil
	else
		self.children = Modal:children_add(self, 10)
	end
	ya.render()
end)

---@type fun(cursor: number): nil
local MUI_update_cursor = ya.sync(function(self, cursor)
	---@cast self PluginState
	if #self.entries ~= 0 then
		self.cursor = ya.clamp(0, self.cursor + cursor, #self.entries - 1)
	else
		self.cursor = 0
	end
	ya.render()
end)

---@type fun(entries: table<number, MountDescription>): nil
local MUI_set_entry_cache = ya.sync(function(self, entries)
	---@cast self PluginState
	self.entries = entries
	self.cursor = math.max(0, math.min(self.cursor or 0, #self.entries - 1))
	ya.render()
end)

local function command_mock()
	return { status = { success = true, }, }, ""
end

---@return table<string, string>
local function sshfs_get_mounted_hosts_map()
	local mounts = {}
	local output, err = Command("mount"):args({ "-t", "fuse.sshfs", }):output()
	if err or not output.status.success then
		M.fail("Failed to read system active mounts %s %s", err, output.stderr)
	end

	for value in output.stdout:gmatch("([^\r\n]+)") do
		local host, location = value:match("(%S+) on (%S+)")
		mounts[host] = location
	end

	return mounts
end

---@param src string
local function blk_split_devices(src)
	local paths = {
		{ "^/dev/sd[a-z]",     "%d+$", }, -- /dev/sda1
		{ "^/dev/nvme%d+n%d+", "p%d+$", }, -- /dev/nvme0n1p1
		{ "^/dev/mmcblk%d+",   "p%d+$", }, -- /dev/mmcblk0p1
		{ "^/dev/disk%d+",     ".+$", }, -- /dev/disk1s1
	}
	for _, p in ipairs(paths) do
		local main = src:match(p[1])
		if main then
			return main, src:sub(#main + 1):match(p[2])
		end
	end
end

---@param tbl table<number, MountDescription>
local function lsblk_enrich_description(tbl)
	if ya.target_os() ~= "linux" then
		return tbl
	end

	local sources, indices = {}, {}
	for i, p in ipairs(tbl) do
		if p.sub and not p.fstype then
			sources[#sources + 1], indices[p.src] = p.src, i
		end
	end
	if #sources == 0 then
		return tbl
	end

	local output, err = Command("lsblk"):args({
		"-p", "-o", "name,fstype", "-J",
	}):args(sources):output()
	if err then
		ya.dbg("Failed to fetch filesystem types for unmounted partitions: " .. err)
		return tbl
	end

	local t = ya.json_decode(output and output.stdout or "")
	for _, p in ipairs(t and t.blockdevices or {}) do
		tbl[indices[p.name]].fstype = p.fstype
	end
	return tbl
end

---@type table<string, FsProvider>
local FS = {
	["fuse.sshfs"] = {
		refresh = true,
		mount = function(desc)
			Command("mkdir"):args({ "-p", desc.target, }):status()
			return Command("sshfs"):args({
				desc.src,
				"-o", "reconnect,follow_symlinks",
				desc.target,
			}):output()
		end,

		unmount = function(desc)
			return Command("fusermount"):args({
				"-u", desc.target,
			}):output()
		end,

		get_possible_mounts = function()
			local mounts = {}
			local activeMounts = sshfs_get_mounted_hosts_map()
			local file = io.open("/etc/hosts", "r")
			if not file then
				M.fail("Failed to read hosts file")
				return {}
			end

			for line in file:lines() do
				local ip, host = line:match("^(%S+)%s+(%S+)$")
				if
						ip and host and
						not ip:match("^#") and
						host ~= "localhost" and
						ip ~= "0.0.0.0"
				then
					local sshhost = host .. ":"
					mounts[#mounts + 1] = {
						src = sshhost,
						label = host,
						dist = activeMounts[sshhost],
						fstype = "fuse.sshfs",
						target = string.format(
							"%s/mount/ssh/%s",
							os.getenv("HOME"),
							host
						),
					}
				end
			end
			file:close()

			return mounts
		end,

		rows = function(entries)
			local rows = {}
			for i, v in ipairs(entries) do
				rows[i] = ui.Row { v.src, v.label or "", v.dist or "", v.fstype or "", }
			end
			return rows
		end,
	},
	["*"] = {
		init = MUI_subscribe_to_mounts,

		get_possible_mounts = function()
			local tbl = {}
			local last
			for _, p in ipairs(fs.partitions()) do
				local main, sub = blk_split_devices(p.src)
				if main and last ~= main then
					if p.src == main then
						last, p.main, p.sub, tbl[#tbl + 1] = p.src, p.src, "", p
					else
						last, tbl[#tbl + 1] = main, { src = main, main = main, sub = "", }
					end
				end
				if sub then
					if tbl[#tbl].sub == "" and tbl[#tbl].main == main then
						tbl[#tbl].sub = nil
					end
					p.main, p.sub, tbl[#tbl + 1] = main, sub, p
				end
			end
			table.sort(lsblk_enrich_description(tbl), function(a, b)
				if a.main == b.main then
					return (a.sub or "") < (b.sub or "")
				else
					return a.main > b.main
				end
			end)
			return tbl
		end,

		operate = function(desc, action)
			if not desc.sub then return command_mock() end
			if ya.target_os() == "macos" then
				return Command("diskutil"):args({ action, desc.src, }):output()
			end

			return Command("udisksctl"):args({ action, "-b", desc.src, }):output()
		end,

		eject = function(desc)
			if ya.target_os() ~= "linux" then return command_mock() end
			Command("udisksctl"):args({ "unmount", "-b", desc.src, }):status()
			return Command("udisksctl"):args({ "power-off", "-b", desc.src, }):output()
		end,

		rows = function(entries)
			local rows = {}
			for _, p in ipairs(entries) do
				if not p.sub then
					rows[#rows + 1] = ui.Row { p.main, }
				elseif p.sub == "" then
					rows[#rows + 1] = ui.Row { p.main, p.label or "", p.dist or "", p.fstype or "", }
				else
					rows[#rows + 1] = ui.Row { "  " .. p.sub, p.label or "", p.dist or "", p.fstype or "", }
				end
			end
			return rows
		end,
	},
}

local MUI_resolve_fsimpl = function(fstype, force)
	if fstype or force then MUI_set_fstype(fstype) end
	fstype = MUI_get_fstype()

	return FS[fstype]
end

function M:new(area)
	self:layout(area)
	return self
end

function M:redraw()
	return {
		ui.Clear(self._area),
		ui.Border(ui.Border.ALL)
				:area(self._area)
				:type(ui.Border.ROUNDED)
				:style(ui.Style():fg("blue"))
				:title(ui.Line("Mount"):align(ui.Line.CENTER)),
		ui.Table(MUI_resolve_fsimpl().rows(self.entries))
				:area(self._area:pad(ui.Pad(1, 2, 1, 2)))
				:header(ui.Row({ "Src", "Label", "Dist", "FSType", }):style(ui.Style():bold()))
				:row(self.cursor)
				:row_style(ui.Style():fg("blue"):underline())
				:widths {
					ui.Constraint.Length(20),
					ui.Constraint.Length(20),
					ui.Constraint.Percentage(70),
					ui.Constraint.Length(10),
				},
	}
end

function M:layout(area)
	local chunks = ui.Layout()
			:constraints({
				ui.Constraint.Percentage(10),
				ui.Constraint.Percentage(80),
				ui.Constraint.Percentage(10),
			})
			:split(area)

	local chunks = ui.Layout()
			:direction(ui.Layout.HORIZONTAL)
			:constraints({
				ui.Constraint.Percentage(10),
				ui.Constraint.Percentage(80),
				ui.Constraint.Percentage(10),
			})
			:split(chunks[2])

	self._area = chunks[2]
end

function M:loop()
	local tx1, rx1 = ya.chan("mpsc")
	local tx2, rx2 = ya.chan("mpsc")

	local function producer()
		while true do
			local cand = self.keys[ya.which { cands = self.keys, silent = true, }] or { run = {}, }
			for _, r in ipairs(type(cand.run) == "table" and cand.run or { cand.run, }) do
				tx1:send(r)
				if r == "quit" then
					MUI_toggle()
					return
				end
			end
		end
	end

	local function consumer1()
		repeat
			local run = rx1:recv()
			if run == "up" then
				MUI_update_cursor(-1)
			elseif run == "down" then
				MUI_update_cursor(1)
			elseif run == "enter" then
				local active = MUI_get_selected_entry()
				if active and active.dist then
					ya.mgr_emit("cd", { active.dist, })
				end
			else
				tx2:send(run)
			end
		until not run or run == "quit"
	end

	local function consumer2()
		repeat
			local run = rx2:recv()
			if run == "quit" then return end

			self.operate(MUI_get_selected_entry(), run)
		until not run
	end

	ya.join(producer, consumer1, consumer2)
end

function M.operate(active, action)
	local impl = MUI_resolve_fsimpl()
	local cb = impl[action] or impl["operate"]
	if not cb then
		M.fail("Action %s unsupported by %s provider", action, MUI_get_fstype())
		return
	end

	local output, err = cb(active, action)
	if not output then
		M.fail("Failed to %s `%s`: %s", action, active.src, err)
	elseif not output.status.success then
		M.fail("Failed to %s `%s`: %s", action, active.src, output.stderr)
	end

	if impl.refresh == true then MUI_refresh() end
end

function M:reflow() return { self, } end

function M:click() end

function M:scroll() end

function M:touch() end

function M:entry(job)
	local cmd = job.args[1]
	if cmd == "__refresh" then
		return MUI_set_entry_cache(
			MUI_resolve_fsimpl().get_possible_mounts()
		)
	end
	local fsimpl = MUI_resolve_fsimpl(cmd, true)

	MUI_toggle()
	MUI_set_entry_cache(
		fsimpl.get_possible_mounts()
	)

	if fsimpl.init then fsimpl.init() end

	M:loop()
end

function M.fail(s, ...) ya.notify { title = "Mount", content = string.format(s, ...), timeout = 10, level = "error", } end

return M
