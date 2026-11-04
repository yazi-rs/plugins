--- @since 26.9.1
--- @sync entry

local function fail(s, ...) error(string.format(s, ...)) end

local state = ya.sync(function()
	local tab = cx.tab
	if not tab then
		return
	end

	local paths = {}
	for _, file in pairs(tab.selected) do
		paths[#paths + 1] = file.path
	end
	if #paths == 0 and tab.current.hovered then
		paths[1] = tab.current.hovered.path
	end
	return tab.current.cwd.physical, paths
end)

local M = {
	suffixes = {
		["7z"] = { "7z" },
		["tar.bz2"] = { "tar", "bzip2" },
		["tar.gz"] = { "tar", "gzip" },
		["tar.xz"] = { "tar", "xz" },
		bz2 = { "bzip2" },
		gz = { "gzip" },
		tar = { "tar" },
		wim = { "wim" },
		xz = { "xz" },
		zip = { "zip" },
	},
}

function M:new() return setmetatable({ children = {} }, { __index = self }) end

function M:init()
	ya.emit("escape", { visual = true })

	self.to, self.paths = state()
	assert(self.to and self.to.spec.is_regular, "Archive creation requires a local directory")
	assert(#self.paths > 0, "No files selected")

	if not self:init_name() then
		return false
	end

	self:init_root()
	self:init_steps()
	return true
end

function M:init_name()
	local name = fs.safename((#self.paths == 1 and self.paths[1].name) or self.to.name or "archive")
	local result = require(".form"):input(name)
	if not result then
		return false
	end

	self.name = assert(fs.safename(result.name ~= "" and result.name or name), "Invalid archive filename")
	self.secret = result.secret
	return true
end

function M:init_root()
	self.root = self.to.path
	for _, p in ipairs(self.paths) do
		while self.root and (not p.parent or not p.parent:starts_with(self.root)) do
			self.root = self.root.parent
		end
	end
	assert(self.root, "Selected files have no shared parent directory")
end

function M:init_steps()
	for i in self.name:gmatch("()%.") do
		local suffix = self.name:sub(i + 1)
		local steps = self.suffixes[suffix]
		if steps then
			self.suffix, self.steps = suffix, steps
			assert(self.secret == "" or steps[1] == "zip" or steps[1] == "7z", "Password encryption requires ZIP or 7z")
			return
		end
	end
	fail("Unsupported archive filename: %s", self.name)
end

function M:init_task()
	local in_ = {
		pool = "plugin",
		scope = rt.scope():child(),
		track = true,
		progress = true,
	}

	self.task = ya.task("custom", in_):name("Compress " .. self.name):spawn()
	self.task:progress { total = 1, workload = 100 }
	return self.task
end

function M:entry()
	ya.async(function()
		local me = self:new()
		local ok, ready = pcall(me.init, me)
		if not ok then
			return ya.notify { title = "Compress", content = tostring(ready), level = "error", timeout = 5 }
		elseif not ready then
			return
		end

		local task = me:init_task()
		local ok, dest = pcall(me.run, me)
		local cleaned, err = me:cleanup()
		if not cleaned then
			task:progress { failed = 1 }
			task:fail(tostring(err))
		elseif not ok then
			task:progress { failed = 1 }
			task:fail(tostring(dest))
		elseif dest then
			task:progress { succeeded = 1 }
			task:succeed { dest }
		else
			task:cancel()
		end
	end)
end

function M:run()
	if not self.task:acquire() then
		return
	end

	local err
	self.tmp, err = fs.unique("dir", Url(self.root:join(self:tmp_name())))
	if not self.tmp then
		fail("Failed to create temporary directory: %s", err)
	end

	local branch, packed = ya.select(self.task, function() return self:pack() end)
	if branch == 2 then
		return self:place(packed)
	end
end

function M:pack()
	local one, prog1, err1 = self:spawn(self:args())
	if #self.steps > 1 then
		local two, prog2, err2 = self:spawn(self:args(true), one:take_stdout())
		prog1, err1, prog2, err2 = ya.join(function() return self:wait(one, 1) end, function() return self:wait(two) end)
		if not prog2 then
			fail("7-Zip failed: %s", err2)
		end
	else
		prog1, err1 = self:wait(one, 0)
	end

	if prog1 then
		self.task:progress { processed = 100 - prog1 }
	else
		fail("7-Zip failed: %s", err1)
	end

	return self.tmp:join(self.name)
end

function M:place(from)
	local dest, err = fs.unique("file", self.to:join(self.name))
	if not dest then
		fail("Failed to choose archive filename: %s", err)
	end
	self.dest = dest

	local ok, err = fs.rename(from, dest)
	if not ok and err and err.kind == "CrossesDevices" then
		ok, err = fs.copy(from, dest)
	end
	if not ok then
		fail("Failed to save archive: %s", err)
	end

	self.dest = nil
	return dest
end

function M:spawn(args, input)
	local child, err
	for _, program in ipairs(self.program and { self.program } or { "7zz", "7z" }) do
		local command = Command(program)
			:arg(args)
			:cwd(tostring(self.root))
			:stdin(input or Command.NULL)
			:stdout(Command.PIPED)
			:stderr(Command.PIPED)

		child, err = command:spawn()
		command:stdin(Command.NULL)

		if child then
			self.children[#self.children + 1], self.program = child, program
			return child
		end
	end
	fail("Failed to start 7-Zip: %s", err)
end

function M:wait(child, progress)
	local stderr, tail, cur, last = "", "", 0, 0
	while true do
		local chunk, event, err = child:read(4096)
		if not chunk then
			return nil, Err("Failed to read 7-Zip output: %s", err)
		elseif event == 2 then
			break
		elseif event == 1 then
			stderr = stderr .. chunk
		end

		if event == progress then
			cur, tail = self.parse_progress(tail .. chunk)
			if cur > last then
				self.task:progress { processed = cur - last }
				last = cur
			end
		end
	end

	local status, err = child:wait()
	if not status then
		return nil, err
	elseif status.code ~= 0 then
		return nil, Err("7-Zip exited with code %s:\n%s", status.code, stderr)
	end
	return last, nil
end

function M:cleanup()
	for _, child in ipairs(self.children) do
		child:start_kill()
	end

	local failure
	for _, child in ipairs(self.children) do
		local status, err = child:wait()
		if not status then
			failure = failure or err
		end
	end

	if failure then
		return false, failure
	end
	if self.dest then
		fs.remove("file", self.dest)
	end
	if self.tmp then
		fs.remove("dir_all", self.tmp)
	end

	return true
end

function M:args(input)
	local step, name = self.steps[input and 2 or 1], self.name
	local stream = not input and #self.steps > 1
	local tarname = name:sub(1, -#self.suffix - 2) .. ".tar"

	local progress = "-bsp1"
	if input then
		progress = "-bsp0"
	elseif stream then
		progress = "-bsp2"
	end

	local args = { "a", "-t" .. step, "-spd", "-sccUTF-8", "-bso0", progress }
	if step == "tar" or step == "zip" or step == "7z" or step == "wim" then
		args[#args + 1], args[#args + 2] = "-spf", "-snl"
	end
	if input then
		args[#args + 1] = "-si" .. tarname
	end
	if stream then
		args[#args + 1] = "-so"
	end
	if self.secret ~= "" then
		args[#args + 1] = "-p" .. self.secret
	end

	args[#args + 1] = "--"
	args[#args + 1] = tostring(self.tmp:join(stream and tarname or name))
	if not input then
		for _, p in ipairs(self.paths) do
			args[#args + 1] = tostring(p:strip_prefix(self.root))
		end
	end

	return args
end

function M:tmp_name()
	return ".tmp_" .. ya.hash(string.format("compress//%s//%s//%.10f", self.to, self.name, ya.time().unix))
end

function M.parse_progress(chunk)
	local percent = 0
	for s in chunk:gmatch("[^\r\n\b]+") do
		percent = tonumber(s:match("^%s*(%d+)%%")) or percent
	end
	return math.min(99, percent), chunk:match("[^\r\n\b]*$")
end

return M
