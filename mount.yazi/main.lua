local toggle_ui = ya.sync(function(self)
	if self.children then
		Modal:children_remove(self.children)
		self.children = nil
	else
		self.children = Modal:children_add(self, 10)
	end
	ya.render()
end)

local subscribe = ya.sync(function(self)
	ps.unsub("mount")
	ps.sub("mount", function() ya.manager_emit("plugin", { self._id, args = "refresh" }) end)
end)

local update_partitions = ya.sync(function(self, partitions)
	self.partitions = partitions
	self.cursor = math.max(0, math.min(self.cursor or 0, #self.partitions - 1))
	ya.render()
end)

local active_partition = ya.sync(function(self) return self.partitions[self.cursor + 1] end)

local update_cursor = ya.sync(function(self, cursor)
	if #self.partitions == 0 then
		self.cursor = 0
	else
		self.cursor = ya.clamp(0, self.cursor + cursor, #self.partitions - 1)
	end
	ya.render()
end)

local M = {
	keys = {
		{ on = "q", run = "quit" },

		{ on = "k", run = "up" },
		{ on = "j", run = "down" },
		{ on = "l", run = { "enter", "quit" } },

		{ on = "<Up>", run = "up" },
		{ on = "<Down>", run = "down" },
		{ on = "<Right>", run = { "enter", "quit" } },

		{ on = "m", run = "mount" },
		{ on = "M", run = "unmount" },
		{ on = "e", run = "eject" },
	},
}

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
end

function M:entry(job)
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
				if active and active.dist then
					ya.manager_emit("cd", { active.dist })
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
			elseif run == "unmount" then
				self.operate("unmount")
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
		if p.sub == "" then
			rows[#rows + 1] = ui.Row { p.main }
		else
			rows[#rows + 1] = ui.Row { p.sub, p.label or "", p.dist or "", p.fstype or "" }
		end
	end

	return {
		ui.Clear(self._area),
		ui.Border(ui.Border.ALL)
			:area(self._area)
			:type(ui.Border.ROUNDED)
			:style(ui.Style():fg("blue"))
			:title(ui.Line("Mount"):align(ui.Line.CENTER)),
		ui.Table(rows)
			:area(self._area:pad(ui.Pad(1, 2, 1, 2)))
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
end

function M.obtain()
	local tbl = {}
	local last
	for _, p in ipairs(fs.partitions()) do
		local main, sub
		if ya.target_os() == "macos" then
			main, sub = p.src:match("^(/dev/disk%d+)(.+)$")
		elseif p.src:find("/dev/nvme", 1, true) == 1 then -- /dev/nvme0n1p1
			main, sub = p.src:match("^(/dev/nvme%d+n%d+)(p%d+)$")
		elseif p.src:find("/dev/sd", 1, true) == 1 then -- /dev/sda1
			main, sub = p.src:match("^(/dev/sd[a-z])(%d+)$")
		end
		if sub then
			if last ~= main then
				last, tbl[#tbl + 1] = main, { src = main, main = main, sub = "" }
			end
			p.main, p.sub, tbl[#tbl + 1] = main, "  " .. sub, p
		end
	end
	table.sort(M.fillin(tbl), function(a, b)
		if a.main == b.main then
			return a.sub < b.sub
		else
			return a.main > b.main
		end
	end)
	return tbl
end

function M.fillin(tbl)
	if ya.target_os() ~= "linux" then
		return tbl
	end

	local sources, indices = {}, {}
	for i, p in ipairs(tbl) do
		if p.sub ~= "" and not p.fstype then
			sources[#sources + 1], indices[#indices + 1] = p.src, i
		end
	end
	if #sources == 0 then
		return tbl
	end

	local output, err = Command("lsblk"):args({ "-n", "-o", "FSTYPE" }):args(sources):output()
	if err then
		ya.dbg("Failed to fetch filesystem types for unmounted partitions: " .. err)
		return tbl
	end

	local i = 1
	for line in output.stdout:gmatch("[^\r\n]+") do
		i, tbl[indices[i]].fstype = i + 1, line
	end
	return tbl
end

function M.operate(type)
	local active = active_partition()
	if not active then
		return
	elseif active.sub == "" then
		return -- TODO: mount/unmount main disk
	end

	local output, err
	if ya.target_os() == "macos" then
		output, err = Command("diskutil"):args({ type, active.src }):output()
	end
	if ya.target_os() == "linux" then
		if type == "eject" then
			Command("udisksctl"):args({ "unmount", "-b", active.src }):status()
			output, err = Command("udisksctl"):args({ "power-off", "-b", active.src }):output()
		else
			output, err = Command("udisksctl"):args({ type, "-b", active.src }):output()
		end
	end

	if not output then
		M.fail("Failed to %s `%s`: %s", type, active.src, err)
	elseif not output.status.success then
		M.fail("Failed to %s `%s`: %s", type, active.src, output.stderr)
	end
end

function M.fail(s, ...) ya.notify { title = "Mount", content = string.format(s, ...), timeout = 10, level = "error" } end

function M:click() end

function M:scroll() end

function M:touch() end

return M
