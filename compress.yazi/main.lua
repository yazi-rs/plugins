--- @since 26.9.1
--- @sync entry

local function fail(s, ...) error(string.format(s, ...), 0) end

local relative = ya.target_family() == "windows" and ".\\" or "./"
local selected = ya.sync(function()
	local tab, urls = cx.active, {}
	for _, file in pairs(tab.selected) do
		urls[#urls + 1] = file.url
	end
	if #urls == 0 and tab.current.hovered then
		urls[1] = tab.current.hovered.url
	end

	local root, to = tab.current.cwd, tab.current.cwd
	if #urls == 0 or not to.spec.is_regular then
		return
	end
	for _, url in ipairs(urls) do
		if not url.spec.is_regular then
			return
		end
		while root and (not url.parent or not url.parent:starts_with(root)) do
			root = root.parent
		end
	end
	if not root then
		return
	end

	local files = {}
	for _, url in ipairs(urls) do
		files[#files + 1] = relative .. tostring(url:strip_prefix(root))
	end
	return {
		root = tostring(root),
		to = tostring(to),
		files = files,
		name = #urls == 1 and urls[1].name or to.name or "archive",
	}
end)

local M = {
	formats = {
		{ on = "z", desc = "zip" },
		{ on = "7", desc = "7z" },
		{ on = "t", desc = "tar" },
		{ on = "g", desc = "tar.gz" },
		{ on = "x", desc = "tar.xz" },
		{ on = "b", desc = "tar.bz2" },
		{ on = "G", desc = "gz" },
		{ on = "X", desc = "xz" },
		{ on = "B", desc = "bz2" },
	},
	codecs = { gz = "gzip", xz = "xz", bz2 = "bzip2" },
	aliases = { tgz = "tar.gz", txz = "tar.xz", tbz = "tar.bz2", tbz2 = "tar.bz2" },
	extra_args = {},
}

function M:canonical(name)
	return (name:gsub("%.([^.]+)$", function(ext) return "." .. (self.aliases[ext] or ext) end))
end

function M:entry()
	ya.async(function()
		local ok, me = pcall(self.prepare, self)
		if ok and not me then
			return
		elseif not ok then
			return ya.notify { title = "Compress", content = tostring(me), level = "error", timeout = 5 }
		end

		me:task()
		local ok, dest = pcall(me.run, me)
		local cleaned, err = me:cleanup()
		if not cleaned or not ok then
			me.task:progress { failed = 1 }
			me.task:fail(tostring(not cleaned and err or dest))
		elseif dest then
			me.task:progress { succeeded = 1 }
			me.task:succeed { dest }
		else
			me.task:cancel()
		end
	end)
end

function M:prepare()
	local me = selected()
	if not me then
		fail("Select local files with a shared parent directory")
	end
	me.root, me.to = Url(me.root), Url(me.to)
	ya.emit("escape", { visual = true })

	local choice = ya.which { cands = self.formats }
	if not choice then
		return
	end
	me.format = self.formats[choice].desc
	setmetatable(me, { __index = self })
	me.codec = self.codecs[me.format:match("[^.]+$")]
	me.tar = me.format:sub(1, 4) == "tar."
	if me.codec and not me.tar then
		local stat = #me.files == 1 and fs.stat(me.root:join(me.files[1]), false)
		-- Yazi exposes regular-file identity through the POSIX file-type bits.
		if not stat or stat.mode & 0xF000 ~= 0x8000 then
			fail("Single-file compression requires one regular file")
		end
	end
	if not me:configure() then
		return
	end
	local value, event = ya.input {
		title = "Create archive:",
		value = me.name .. "." .. me.format,
		pos = { "top-center", y = 3, w = 50 },
	}
	if event ~= 1 then
		return
	elseif value == "" then
		value = me.name .. "." .. me.format
	end
	if fs.safename(value) ~= value then
		fail("Invalid archive filename")
	end
	local alias = self.aliases[value:match("%.([^.]+)$")]
	me.name = (value:sub(-#me.format - 1) == "." .. me.format or alias == me.format) and value
		or value .. "." .. me.format
	me.tarname = me.tar and me:canonical(me.name):gsub("%.[^.]+$", "")
	if me.encrypt then
		for _, title in ipairs { "Password:", "Confirm password:" } do
			local value, event = ya.input { title = title, obscure = true, pos = { "top-center", y = 3, w = 50 } }
			if event ~= 1 then
				return
			elseif value == "" then
				fail("Password cannot be empty")
			elseif me.format == "zip" and (#value > 99 or value:find("[^\32-\127]")) then
				fail("ZIP passwords must contain 1-99 ASCII characters")
			elseif me.password and value ~= me.password then
				fail("Passwords do not match")
			end
			me.password = value
		end
	end
	return me
end

function M:configure()
	if self.format == "tar" then
		return true
	end
	while true do
		local cands = {
			{ on = "l", desc = "Level: " .. (self.level or "default") },
			{ on = "c", desc = "Create" },
		}
		if not self.codec then
			table.insert(cands, 1, { on = "p", desc = "Password: " .. (self.encrypt and "on" or "off") })
		end
		if self.format == "7z" then
			table.insert(cands, 2, { on = "h", desc = "Hide filenames: " .. (self.headers and "on" or "off") })
		end
		local choice = ya.which { cands = cands }
		if not choice then
			return
		end
		local key = cands[choice].on
		if key == "c" then
			return true
		elseif key == "p" then
			self.encrypt = not self.encrypt
			self.headers = self.encrypt and self.headers
		elseif key == "h" then
			self.headers = not self.headers
			self.encrypt = self.encrypt or self.headers
		elseif key == "l" then
			local value, event = ya.input {
				title = "Compression level (0-9):",
				value = self.level and tostring(self.level) or "",
				pos = { "top-center", y = 3, w = 50 },
			}
			if event == 1 then
				local level = tonumber(value)
				if value == "" or level and level % 1 == 0 and level >= 0 and level <= 9 then
					self.level = level and math.floor(level)
				else
					ya.notify {
						title = "Compress",
						content = "Compression level must be an integer from 0 to 9",
						level = "error",
						timeout = 5,
					}
				end
			end
		end
	end
end

function M:task()
	local scope = rt.scope():child()
	self.cancelled = scope:child()
	self.task = ya.task("custom", { pool = "plugin", scope = scope, track = true, progress = true })
		:name("Compress " .. self.name)
		:spawn()
	self.task:progress { total = 1, workload = 100 }
end

function M:tempdir()
	local err
	for _, base in ipairs { self.to, self.root, Url(tostring(rt.preview.cache_dir)) } do
		local inside = false
		for _, file in ipairs(self.files) do
			if base:starts_with(self.root:join(file)) then
				inside = true
				break
			end
		end
		if not inside then
			self.tmp, err = fs.unique("dir", base:join(".tmp_compress"))
			if self.tmp then
				return
			elseif base == self.to then
				break
			end
		end
	end
	fail("Failed to create temporary directory: %s", err or "selected files contain the temporary storage")
end

function M:run()
	if not self.task:acquire() then
		return
	end

	-- Reserve paths outside cancellable branches so cleanup always owns them.
	self:tempdir()
	if ya.select(self.task, function() self:pack() end) == 1 then
		return
	end

	local err
	self.dest, err = fs.unique("file", self.to:join(self.name))
	if not self.dest then
		fail("Failed to choose archive filename: %s", err)
	end
	local from = self.tmp:join(self.name)
	-- Filesystem operations can outlive a cancelled Lua future.
	local moved, err = fs.rename(from, self.dest)
	if not moved and err and err.kind == "CrossesDevices" then
		moved, err = fs.copy(from, self.dest)
	end
	if not moved then
		fail("Failed to save archive: %s", err)
	elseif self.cancelled:cancelled() then
		return
	end
	local dest = self.dest
	self.dest = nil
	return dest
end

function M:spawn(kind, files, output, input, stream)
	-- Inputs stay relative so -spf preserves directories without storing absolute paths.
	local args = { "a", "-t" .. kind, "-spd", "-sccUTF-8", "-bso0", input and "-bsp0" or stream and "-bsp2" or "-bsp1" }
	if kind == "tar" or kind == "zip" or kind == "7z" then
		args[#args + 1], args[#args + 2] = "-spf", "-snl"
	end
	if kind ~= "tar" then
		if self.password then
			args[#args + 1] = "-p" .. self.password
			if kind == "zip" then
				args[#args + 1] = "-mem=AES256"
			end
		end
		if self.headers then
			args[#args + 1] = "-mhe=on"
		end
		if self.level then
			args[#args + 1] = "-mx=" .. self.level
		end
	end
	if stream then
		args[#args + 1] = "-so"
	end
	if input then
		args[#args + 1] = "-si" .. self.tarname
	end
	local err
	-- The shared archive spawner cannot set the source working directory.
	for _, program in ipairs(self.program and { self.program } or { "7zz", "7z" }) do
		if program == "7z" and not self.program then
			local info = Command(program):arg("--help"):output()
			if info and info.stdout:find("p7zip", 1, true) then
				fail("Archive creation requires current 7-Zip (7zz). Legacy p7zip is not supported.")
			end
		end
		local command = Command(program)
			:arg(args)
			:arg(self.extra_args[kind] or {})
			:arg(output)
			:arg(files)
			:cwd(tostring(self.root.path))
			:stdin(input or Command.NULL)
			:stdout(Command.PIPED)
			:stderr(Command.PIPED)
		local child
		child, err = command:spawn()
		-- Command retains its pipe handle after spawning, which would prevent broken-pipe detection.
		command:stdin(Command.NULL)
		if child then
			self.program = program
			self.children = self.children or {}
			self.children[#self.children + 1] = child
			return child
		end
	end
	fail("Failed to start 7-Zip: %s", err)
end

function M:wait(child, progress)
	local parse = require("extract").parse_progress
	local diagnostic, tail, last = "", "", 0
	while true do
		local chunk, event, err = child:read(4096)
		if not chunk then
			fail("Failed to read 7-Zip output: %s", err)
		elseif event == 2 then
			break
		elseif event == 1 then
			diagnostic = (diagnostic .. chunk):sub(-8192)
		end
		if event == progress then
			local percent
			percent, tail = parse(tail .. chunk)
			percent = math.min(99, percent)
			if percent > last then
				self.task:progress { processed = percent - last }
				last = percent
			end
		end
	end
	local status, err = child:wait()
	if not status or not status.success then
		return false, diagnostic ~= "" and diagnostic or err or "exit code " .. tostring(status.code)
	end
	return true, nil, last
end

function M:pack()
	local source
	if self.tar then
		-- Even with -so, 7-Zip updates an existing archive argument, so use a fresh path.
		source = self:spawn("tar", self.files, tostring(self.tmp:join(self.tarname)), nil, true)
	end
	local child = self:spawn(
		self.codec or self.format,
		source and {} or self.files,
		tostring(self.tmp:join(self.name)),
		source and source:take_stdout()
	)
	-- TAR progress follows the pipe's backpressure while the compressor runs.
	local ok, err, last = self:wait(source or child, source and 1 or 0)
	if source then
		local written, problem = self:wait(child)
		-- A failed compressor can break TAR's pipe, so report the writer's error first.
		if not written then
			fail("7-Zip failed: %s", problem)
		end
	end
	if not ok then
		fail("7-Zip failed: %s", err)
	end
	self.children = nil
	self.task:progress { processed = 100 - last }
end

function M:cleanup()
	local failure
	for _, child in ipairs(self.children or {}) do
		child:start_kill()
	end
	for _, child in ipairs(self.children or {}) do
		local status, err = child:wait()
		if not status then
			failure = failure or err
		end
	end
	if failure then
		return false, failure
	end
	for _, item in ipairs { { "file", self.dest }, { "dir_all", self.tmp } } do
		if item[2] then
			local removed, err = fs.remove(item[1], item[2])
			if not removed then
				failure = failure or err
			end
		end
	end
	return failure == nil, failure
end

return M
