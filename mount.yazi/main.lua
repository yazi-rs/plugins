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
		{ on = "l", run = "right" },

		{ on = "<Up>", run = "up" },
		{ on = "<Down>", run = "down" },
		{ on = "<Right>", run = "right" },

		{ on = "m", run = "mount" },
		{ on = "M", run = "umount" },
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
			local cand = self.keys[ya.which { cands = self.keys, silent = true }]
			if cand then
				tx1:send(cand.run)
				if cand.run == "quit" then
					toggle_ui()
					break
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
			elseif run == "right" then
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
			elseif run == "umount" then
				self.operate("umount")
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
			rows[#rows + 1] = ui.Row { p.sub, p.label, p.dist or "", p.fstype }
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
	local last = { false, nil }
	for _, p in ipairs(fs.partitions()) do
		local main, sub = p.src:match("^(/dev/disk%d+)(.*)$")
		if sub == "" then
			p.main, p.sub, last = main, sub, { true, p }
		elseif not p.fstype then
		else
			if last[1] then
				tbl[#tbl + 1], last[1] = last[2], false
			end
			p.main, p.sub, tbl[#tbl + 1] = last[2].main, "  " .. sub, p
		end
	end
	table.sort(tbl, function(a, b)
		if a.main == b.main then
			return a.sub < b.sub
		else
			return a.main > b.main
		end
	end)
	return tbl
end

function M.operate(type)
	local active = active_partition()
	if not active then
		return
	elseif active.sub == "" then
		return -- TODO: mount/umount main disk
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
