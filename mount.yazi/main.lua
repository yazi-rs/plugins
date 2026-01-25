--- @since 25.12.29



local toggle_ui = ya.sync(function(self)
	if self.children then
		Modal:children_remove(self.children)
		self.children = nil
	else
		self.children = Modal:children_add(self, 10)
	end
	ui.render()
end)

-- Store config in sync context so it persists across plugin invocations
local save_config = ya.sync(function(self, config)
	self.saved_config = config
end)

local load_config = ya.sync(function(self)
	return self.saved_config
end)

local subscribe = ya.sync(function(self)
	ps.unsub("mount")
	ps.sub("mount", function() ya.emit("plugin", { self._id, "refresh" }) end)
end)

local update_partitions = ya.sync(function(self, partitions)
	self.partitions = partitions
	self.cursor = math.max(0, math.min(self.cursor or 0, #self.partitions - 1))
	ui.render()
end)

local active_partition = ya.sync(function(self) return self.partitions[self.cursor + 1] end)

local update_cursor = ya.sync(function(self, cursor)
	if #self.partitions == 0 then
		self.cursor = 0
	else
		self.cursor = ya.clamp(0, self.cursor + cursor, #self.partitions - 1)
	end
	ui.render()
end)

local DEFAULT_KEYS = {
	quit = "q",
	up = "k",
	down = "j",
	enter = "l",
	mount = "m",
	unmount = "u",
	eject = "e",
}

-- Module table M - defined early so functions can reference it
local M = {
	keys = nil, -- will be set after build_keymap is defined
	user_keys = {},
	symlink_opts = {
		enabled = false,
		dir = nil, -- defaults to $HOME
	},
	show_help = true,
	filter_opts = {
		-- Filter out partitions mounted at these paths
		exclude_mounts = { "/", "/boot", "/boot/efi" },
		-- Filter out partitions with these filesystem types
		exclude_fstypes = {},
		-- Filter out drives (main devices) that contain the root partition
		exclude_root_drive = true,
		-- Additional device patterns to exclude (e.g., {"^/dev/sda", "^/dev/nvme0n1"})
		exclude_devices = {},
	},
}

-- Helper to get keys for an action (supports single key or array of keys)
local function get_action_keys(action)
	local user_key = M and M.user_keys and M.user_keys[action]
	local default_key = DEFAULT_KEYS[action]
	
	if user_key then
		-- User provided key(s)
		if type(user_key) == "table" then
			return user_key
		else
			return { user_key }
		end
	else
		-- Default key
		return { default_key }
	end
end

local function build_keymap()
	local keymap = {}
	
	-- Helper to add key(s) for an action
	local function add_keys(action, run)
		local keys = get_action_keys(action)
		for _, key in ipairs(keys) do
			keymap[#keymap + 1] = { on = key, run = run }
		end
	end
	
	-- Add user-configurable keys
	add_keys("quit", "quit")
	add_keys("up", "up")
	add_keys("down", "down")
	add_keys("enter", { "enter", "quit" })
	add_keys("mount", "mount")
	add_keys("unmount", "unmount")
	add_keys("eject", "eject")
	
	-- Add hardcoded alternate keys
	keymap[#keymap + 1] = { on = "<Esc>", run = "quit" }
	keymap[#keymap + 1] = { on = "<Left>", run = "quit" }
	keymap[#keymap + 1] = { on = "<Enter>", run = { "enter", "quit" } }
	keymap[#keymap + 1] = { on = "<Up>", run = "up" }
	keymap[#keymap + 1] = { on = "<Down>", run = "down" }
	keymap[#keymap + 1] = { on = "<Right>", run = { "enter", "quit" } }
	
	return keymap
end

-- Set M.keys now that build_keymap is defined
M.keys = build_keymap()

local function get_config()
	local saved = load_config()
	if saved then
		-- Restore config from sync context
		M.symlink_opts = saved.symlink_opts or M.symlink_opts
		M.filter_opts = saved.filter_opts or M.filter_opts
		M.show_help = saved.show_help ~= nil and saved.show_help or M.show_help
		if saved.user_keys then
			M.user_keys = saved.user_keys
			-- Rebuild keymap with restored user keys
			M.keys = build_keymap()
		end
	end
	return M
end

local function get_symlink_dir()
	local config = get_config()
	return config.symlink_opts.dir or os.getenv("HOME")
end

local function sanitize_name(name)
	if not name or name == "" then
		return nil
	end
	-- Replace slashes and null bytes with underscores, trim whitespace
	return name:gsub("[/%z]", "_"):gsub("^%s+", ""):gsub("%s+$", "")
end

local function get_symlink_name(partition)
	local name = partition.label and partition.label ~= "" and partition.label or partition.sub
	-- Fallback: extract device name from src (e.g., /dev/sdb1 -> sdb1)
	if not name and partition.src then
		name = partition.src:match("^/dev/(.+)$")
	end
	return sanitize_name(name)
end

local function get_symlink_path(partition)
	local name = get_symlink_name(partition)
	if not name then
		return nil
	end
	return get_symlink_dir() .. "/" .. name
end

-- Helper to get navigation path before unmounting (to release drive)
local function get_unmount_nav_path(active)
	local config = get_config()
	local nav_path = nil
	
	if not active.sub then
		-- It's a disk - find first mounted partition
		local partitions = M.get_disk_partitions(active.src)
		for _, p in ipairs(partitions) do
			if p.dist then
				local symlink_path = get_symlink_path(p)
				if config.symlink_opts.enabled and symlink_path then
					nav_path = config.symlink_opts.dir or os.getenv("HOME")
				else
					-- Navigate to parent of mount point
					nav_path = p.dist:match("(.+)/[^/]*$") or "/"
				end
				break
			end
		end
	else
		-- It's a partition
		local symlink_path = get_symlink_path(active)
		if config.symlink_opts.enabled and symlink_path then
			nav_path = config.symlink_opts.dir or os.getenv("HOME")
		elseif active.dist then
			-- Navigate to parent of mount point
			nav_path = active.dist:match("(.+)/[^/]*$") or "/"
		end
	end
	
	return nav_path
end

local function create_symlink(partition)
	local config = get_config()
	
	if not config.symlink_opts.enabled then
		return
	end
	
	if not partition.dist then
		return
	end

	local path = get_symlink_path(partition)
	if not path then
		return
	end

	Command("ln"):arg({ "-sfn", partition.dist, path }):status()
end

local function remove_symlink(partition)
	-- Always attempt cleanup regardless of enabled setting
	-- This ensures symlinks are removed even if config changed or state was reset
	
	if not partition.dist then
		return
	end

	local path = get_symlink_path(partition)
	if not path then
		return
	end

	-- Only remove if it's a symlink (not a regular file/directory)
	local is_symlink = Command("test"):arg({ "-L", path }):status()
	if not is_symlink or not is_symlink.success then
		return
	end

	-- Verify the symlink actually points to the partition's mount point
	-- This prevents accidentally removing symlinks not created by this plugin
	local readlink = Command("readlink"):arg({ "-f", path }):output()
	if readlink and readlink.status.success then
		local target = readlink.stdout:gsub("%s+$", "")
		if target == partition.dist then
			Command("rm"):arg({ path }):status()
		end
	end
end

function M:setup(opts)
	opts = opts or {}
	if opts.keys then
		for action, key in pairs(opts.keys) do
			if DEFAULT_KEYS[action] ~= nil then
				M.user_keys[action] = key
			end
		end
		M.keys = build_keymap()
	end
	if opts.symlinks ~= nil then
		M.symlink_opts.enabled = opts.symlinks
	end
	if opts.symlink_dir then
		M.symlink_opts.dir = opts.symlink_dir
	end
	if opts.exclude_mounts ~= nil then
		M.filter_opts.exclude_mounts = opts.exclude_mounts
	end
	if opts.exclude_fstypes ~= nil then
		M.filter_opts.exclude_fstypes = opts.exclude_fstypes
	end
	if opts.exclude_root_drive ~= nil then
		M.filter_opts.exclude_root_drive = opts.exclude_root_drive
	end
	if opts.exclude_devices ~= nil then
		M.filter_opts.exclude_devices = opts.exclude_devices
	end
	if opts.show_help ~= nil then
		M.show_help = opts.show_help
	end
	
	-- Save config to sync context so it persists across plugin invocations
	save_config({
		symlink_opts = M.symlink_opts,
		filter_opts = M.filter_opts,
		show_help = M.show_help,
		user_keys = M.user_keys,
	})
end

local function get_key(action)
	local user_key = M.user_keys and M.user_keys[action]
	if user_key then
		if type(user_key) == "table" then
			return table.concat(user_key, "/")
		else
			return user_key
		end
	end
	return DEFAULT_KEYS[action]
end

local function build_help_line()
	local hints = {
		{ key = get_key("enter"), action = "mount/eject" },
		{ key = get_key("mount"), action = "mount" },
		{ key = get_key("unmount"), action = "unmount" },
		{ key = get_key("eject"), action = "eject" },
		{ key = get_key("quit"), action = "quit" },
	}

	local spans = {}
	for i, hint in ipairs(hints) do
		spans[#spans + 1] = ui.Span(hint.key):style(ui.Style():fg("blue"):bold())
		spans[#spans + 1] = ui.Span(" " .. hint.action)
		if i < #hints then
			spans[#spans + 1] = ui.Span("  ")
		end
	end

	return ui.Line(spans):align(ui.Align.CENTER)
end

function M:new(area)
	self:layout(area)
	return self
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

	-- Calculate inner area for the table (accounting for border and help line)
	if M.show_help then
		-- Reserve 1 line at the bottom for help text (inside the border)
		self._table_area = self._area:pad(ui.Pad(1, 2, 2, 2))
		-- Help line area (1 line above bottom border)
		self._help_area = ui.Rect {
			x = self._area.x + 2,
			y = self._area.y + self._area.h - 2,
			w = self._area.w - 4,
			h = 1,
		}
	else
		self._table_area = self._area:pad(ui.Pad(1, 2, 1, 2))
		self._help_area = nil
	end
end

function M:entry(job)
	-- Restore config (including keybindings) from sync context
	get_config()

	if job.args[1] == "refresh" then
		return update_partitions(self.obtain())
	end

	toggle_ui()
	update_partitions(self.obtain())
	subscribe()

	local tx1, rx1 = ya.chan("mpsc")
	local tx2, rx2 = ya.chan("mpsc")
	function producer()
		while true do
			local cand = self.keys[ya.which { cands = self.keys, silent = true }] or { run = {} }
			for _, r in ipairs(type(cand.run) == "table" and cand.run or { cand.run }) do
				tx1:send(r)
				if r == "quit" then
					toggle_ui()
					return
				end
			end
		end
	end

	function consumer1()
		repeat
			local run = rx1:recv()
			if run == "quit" then
				tx2:send(run)
				break
			elseif run == "up" then
				update_cursor(-1)
			elseif run == "down" then
				update_cursor(1)
			elseif run == "enter" then
				local active = active_partition()
				if active then
					local is_mounted = false
					if active.dist then
						-- Partition is mounted
						is_mounted = true
					elseif not active.sub then
						-- It's a disk - check if any partitions are mounted
						local partitions = M.get_disk_partitions(active.src)
						for _, p in ipairs(partitions) do
							if p.dist then
								is_mounted = true
								break
							end
						end
					end
					
					if is_mounted then
						-- Mounted: navigate away, unmount and eject
						tx2:send("unmount_and_cd")
					else
						-- Unmounted: mount and navigate to it
						tx2:send("mount_and_cd")
					end
				end
			else
				tx2:send(run)
			end
		until not run
	end

	function consumer2()
		repeat
			local run = rx2:recv()
			if run == "quit" then
				break
			elseif run == "mount" then
				self.operate("mount")
			elseif run == "mount_and_cd" then
				local nav_path = self.operate("mount")
				if nav_path then
					ya.emit("cd", { nav_path })
				end
			elseif run == "unmount" then
				-- Navigate away first to release the drive if needed
				local active = active_partition()
				if active then
					local nav_path = get_unmount_nav_path(active)
					if nav_path then
						ya.emit("cd", { nav_path })
					end
				end
				self.operate("unmount")
			elseif run == "unmount_and_cd" then
				local active = active_partition()
				if active then
					-- Navigate away first to release the drive
					local nav_path = get_unmount_nav_path(active)
					if nav_path then
						ya.emit("cd", { nav_path })
					end
					
					-- Unmount and eject
					self.operate("unmount")
					self.operate("eject")
				end
			elseif run == "eject" then
				self.operate("eject")
			end
		until not run
	end

	ya.join(producer, consumer1, consumer2)
end

function M:reflow() return { self } end

function M:redraw()
	local rows = {}
	for _, p in ipairs(self.partitions or {}) do
		if not p.sub then
			rows[#rows + 1] = ui.Row { p.main }
		elseif p.sub == "" then
			rows[#rows + 1] = ui.Row { p.main, p.label or "", p.dist or "", p.fstype or "" }
		else
			rows[#rows + 1] = ui.Row { "  " .. p.sub, p.label or "", p.dist or "", p.fstype or "" }
		end
	end

	local elements = {
		ui.Clear(self._area),
		ui.Border(ui.Edge.ALL)
			:area(self._area)
			:type(ui.Border.ROUNDED)
			:style(ui.Style():fg("blue"))
			:title(ui.Line("Mount"):align(ui.Align.CENTER)),
		ui.Table(rows)
			:area(self._table_area)
			:header(ui.Row({ "Src", "Label", "Dist", "FSType" }):style(ui.Style():bold()))
			:row(self.cursor)
			:row_style(ui.Style():fg("blue"):underline())
			:widths {
				ui.Constraint.Length(20),
				ui.Constraint.Length(20),
				ui.Constraint.Percentage(70),
				ui.Constraint.Length(10),
			},
	}

	if M.show_help and self._help_area then
		elements[#elements + 1] = ui.Text({ build_help_line() }):area(self._help_area)
	end

	return elements
end

-- Find the device that contains the root filesystem
function M.find_root_drive()
	-- First try the simple approach for non-encrypted setups
	local partitions = fs.partitions()
	for _, p in ipairs(partitions) do
		if p.dist == "/" then
			local main = M.split(p.src)
			if main then
				return main
			end
		end
	end

	-- For encrypted setups (LUKS), use lsblk -s to trace back to the physical device
	if ya.target_os() == "linux" then
		local output = Command("findmnt"):arg({ "-n", "-o", "SOURCE", "/" }):output()
		if output and output.status.success then
			local source = output.stdout:gsub("%s+$", "")
			-- If it's a mapper device or dm-*, find the underlying physical device
			if source:match("^/dev/mapper/") or source:match("^/dev/dm%-") then
				-- Use lsblk -s (reverse dependency) to get the full chain
				local lsblk_out = Command("lsblk"):arg({ "-s", "-lno", "NAME", source }):output()
				if lsblk_out and lsblk_out.status.success then
					-- Parse each line to find the physical disk
					for line in lsblk_out.stdout:gmatch("[^\r\n]+") do
						local dev = "/dev/" .. line
						local main, sub = M.split(dev)
						-- If main matches dev and sub is nil, we found the disk
						if main and not sub and main == dev then
							return main
						end
					end
				end
			end
		end
	end

	return nil
end

-- Check if a partition should be filtered out
function M.should_filter(partition, root_drive)
	local config = get_config()
	-- Check excluded mount points
	if partition.dist then
		for _, mount in ipairs(config.filter_opts.exclude_mounts) do
			if partition.dist == mount then
				return true
			end
		end
	end

	-- Check excluded filesystem types
	local config = get_config()
	if partition.fstype then
		for _, fstype in ipairs(config.filter_opts.exclude_fstypes) do
			if partition.fstype == fstype then
				return true
			end
		end
	end

	-- Check excluded device patterns
	local config = get_config()
	for _, pattern in ipairs(config.filter_opts.exclude_devices) do
		if partition.src and partition.src:match(pattern) then
			return true
		end
	end

	return false
end

-- Check if a main drive should be filtered (contains root partition)
function M.should_filter_drive(main_device, root_drive)
	local config = get_config()
	if config.filter_opts.exclude_root_drive and root_drive then
		return main_device == root_drive
	end
	return false
end

function M.obtain()
	local config = get_config()
	local tbl = {}
	local last
	local root_drive = config.filter_opts.exclude_root_drive and M.find_root_drive() or nil

	for _, p in ipairs(fs.partitions()) do
		local main, sub = M.split(p.src)

		-- Skip if this partition or its drive should be filtered
		if main and M.should_filter_drive(main, root_drive) then
			-- Skip partitions belonging to the root drive
			goto continue
		end

		if M.should_filter(p, root_drive) then
			goto continue
		end

		if main and last ~= main then
			if p.src == main then
				last, p.main, p.sub, tbl[#tbl + 1] = p.src, p.src, "", p
			else
				last, tbl[#tbl + 1] = main, { src = main, main = main, sub = "" }
			end
		end
		if sub then
			if tbl[#tbl] and tbl[#tbl].sub == "" and tbl[#tbl].main == main then
				tbl[#tbl].sub = nil
			end
			p.main, p.sub, tbl[#tbl + 1] = main, sub, p
		end

		::continue::
	end
	table.sort(M.fillin(tbl), function(a, b)
		if a.main == b.main then
			return (a.sub or "") < (b.sub or "")
		else
			return a.main > b.main
		end
	end)
	return tbl
end

function M.split(src)
	local pats = {
		{ "^/dev/sd[a-z]", "%d+$" }, -- /dev/sda1
		{ "^/dev/nvme%d+n%d+", "p%d+$" }, -- /dev/nvme0n1p1
		{ "^/dev/mmcblk%d+", "p%d+$" }, -- /dev/mmcblk0p1
		{ "^/dev/disk%d+", ".+$" }, -- /dev/disk1s1
		{ "^/dev/sr%d+", ".+$" }, -- /dev/sr0
	}
	for _, p in ipairs(pats) do
		local main = src:match(p[1])
		if main then
			return main, src:sub(#main + 1):match(p[2])
		end
	end
end

function M.fillin(tbl)
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

	local output, err = Command("lsblk"):arg({ "-p", "-o", "name,fstype", "-J" }):arg(sources):output()
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

-- Get all partitions belonging to a disk (with fstype info)
function M.get_disk_partitions(disk_src)
	local partitions = {}
	local sources = {}
	for _, p in ipairs(fs.partitions()) do
		local main = M.split(p.src)
		if main == disk_src and p.src ~= disk_src then
			partitions[#partitions + 1] = p
			if not p.fstype then
				sources[#sources + 1] = p.src
			end
		end
	end

	-- Fetch fstype for unmounted partitions using lsblk
	if #sources > 0 and ya.target_os() == "linux" then
		local output = Command("lsblk"):arg({ "-p", "-o", "name,fstype", "-J" }):arg(sources):output()
		if output and output.status.success then
			local t = ya.json_decode(output.stdout or "")
			if t and t.blockdevices then
				local fstype_map = {}
				for _, dev in ipairs(t.blockdevices) do
					fstype_map[dev.name] = dev.fstype
				end
				for _, p in ipairs(partitions) do
					if not p.fstype and fstype_map[p.src] then
						p.fstype = fstype_map[p.src]
					end
				end
			end
		end
	end

	return partitions
end

-- Operate on an entire disk (mount/unmount/eject all partitions)
function M.operate_disk(type, disk)
	local partitions = M.get_disk_partitions(disk.src)

	if ya.target_os() == "macos" then
		local output, err
		if type == "mount" then
			output, err = Command("diskutil"):arg({ "mountDisk", disk.src }):output()
		elseif type == "unmount" then
			output, err = Command("diskutil"):arg({ "unmountDisk", disk.src }):output()
		elseif type == "eject" then
			output, err = Command("diskutil"):arg({ "eject", disk.src }):output()
		end
		if not output then
			M.fail("Failed to %s disk `%s`: %s", type, disk.src, err)
		elseif not output.status.success then
			M.fail("Failed to %s disk `%s`: %s", type, disk.src, output.stderr)
		end
		return
	end

	if ya.target_os() == "linux" then
		if type == "mount" then
			-- Check if all partitions are already mounted
			local all_mounted = true
			local has_mountable = false
			for _, p in ipairs(partitions) do
				if p.fstype and p.fstype ~= "" then
					has_mountable = true
					if not p.dist then
						all_mounted = false
						break
					end
				end
			end

			if has_mountable and all_mounted then
				ya.notify { title = "Mount", content = "Disk `" .. disk.src .. "` is already mounted", timeout = 5, level = "warn" }
				return
			end

			-- Mount all unmounted partitions that have a filesystem
			local mounted_sources = {}
			for _, p in ipairs(partitions) do
				if not p.dist and p.fstype and p.fstype ~= "" then
					local output = Command("udisksctl"):arg({ "mount", "-b", p.src }):output()
					if output and output.status.success then
						mounted_sources[p.src] = true
					end
				end
			end

			-- Create symlinks for all mounted partitions
			local nav_path = nil
			if next(mounted_sources) then
				-- Fetch fresh partition info to get mount points
				for _, p in ipairs(fs.partitions()) do
					if mounted_sources[p.src] and p.dist then
						create_symlink(p)
						-- Set navigation path (prefer symlink if created)
						if not nav_path then
							local symlink_path = get_symlink_path(p)
							local config = get_config()
							if config.symlink_opts.enabled and symlink_path then
								nav_path = symlink_path
							else
								nav_path = p.dist
							end
						end
					end
				end
				return nav_path
			else
				ya.notify { title = "Mount", content = "No mountable partitions found on `" .. disk.src .. "`", timeout = 5, level = "warn" }
				return nil
			end
		elseif type == "unmount" then
			-- Check if all partitions are already unmounted
			local any_mounted = false
			for _, p in ipairs(partitions) do
				if p.dist then
					any_mounted = true
					break
				end
			end

			if not any_mounted then
				ya.notify { title = "Mount", content = "Disk `" .. disk.src .. "` is already unmounted", timeout = 5, level = "warn" }
				return
			end

			-- Unmount all mounted partitions
			local errors = {}
			for _, p in ipairs(partitions) do
				if p.dist then
					remove_symlink(p)
					local output = Command("udisksctl"):arg({ "unmount", "-b", p.src }):output()
					if not output or not output.status.success then
						errors[#errors + 1] = p.src
					end
				end
			end
			if #errors > 0 then
				M.fail("Failed to unmount: %s", table.concat(errors, ", "))
			end
		elseif type == "eject" then
			-- Unmount all mounted partitions first
			for _, p in ipairs(partitions) do
				if p.dist then
					remove_symlink(p)
					Command("udisksctl"):arg({ "unmount", "-b", p.src }):status()
				end
			end
			-- Power off the disk
			local output, err = Command("udisksctl"):arg({ "power-off", "-b", disk.src }):output()
			if not output then
				M.fail("Failed to eject disk `%s`: %s", disk.src, err)
			elseif not output.status.success then
				M.fail("Failed to eject disk `%s`: %s", disk.src, output.stderr)
			end
		end
	end
end

function M.operate(type)
	local active = active_partition()
	if not active then
		return nil
	elseif not active.sub then
		-- Operating on entire disk
		return M.operate_disk(type, active)
	end

	-- Check if partition is already in the desired state
	if type == "mount" and active.dist then
		ya.notify { title = "Mount", content = "Partition `" .. active.src .. "` is already mounted", timeout = 5, level = "warn" }
		return nil
	elseif type == "unmount" and not active.dist then
		ya.notify { title = "Mount", content = "Partition `" .. active.src .. "` is already unmounted", timeout = 5, level = "warn" }
		return nil
	end

	-- For unmount/eject, remove symlink before the operation
	local should_remove_symlink = (type == "unmount" or type == "eject") and active.dist
	if should_remove_symlink then
		remove_symlink(active)
	end

	local output, err
	if ya.target_os() == "macos" then
		output, err = Command("diskutil"):arg({ type, active.src }):output()
	end
	if ya.target_os() == "linux" then
		if type == "eject" and active.src:match("^/dev/sr%d+") then
			Command("udisksctl"):arg({ "unmount", "-b", active.src }):status()
			output, err = Command("eject"):arg({ "--traytoggle", active.src }):output()
		elseif type == "eject" then
			Command("udisksctl"):arg({ "unmount", "-b", active.src }):status()
			output, err = Command("udisksctl"):arg({ "power-off", "-b", active.src }):output()
		else
			output, err = Command("udisksctl"):arg({ type, "-b", active.src }):output()
		end
	end

	if not output then
		M.fail("Failed to %s `%s`: %s", type, active.src, err)
		return nil
	elseif not output.status.success then
		M.fail("Failed to %s `%s`: %s", type, active.src, output.stderr)
		return nil
	elseif type == "mount" then
		-- On successful mount, create symlink
		-- Re-fetch partition info to get the mount point
		local partitions = M.obtain()
		for _, p in ipairs(partitions) do
			if p.src == active.src and p.dist then
				create_symlink(p)
				-- Return navigation path (prefer symlink if created)
				local symlink_path = get_symlink_path(p)
				local config = get_config()
				if config.symlink_opts.enabled and symlink_path then
					return symlink_path
				else
					return p.dist
				end
			end
		end
	end
	return nil
end

function M.fail(...) ya.notify { title = "Mount", content = string.format(...), timeout = 10, level = "error" } end

function M:click() end

function M:scroll() end

function M:touch() end

return M
