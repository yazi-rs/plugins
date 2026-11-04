--- @sync entry

local render = ya.sync(ui.render)

local M = {}

function M:new(area)
	local me = setmetatable({ _area = area }, { __index = self })
	me:layout()
	return me
end

function M:entry()
	self.values[self.focused] = cx.input.alt.value
	self.focused = self.focused == "name" and "secret" or "name"
	ui.render()
end

function M:layout()
	local rows = ui.Layout()
		:constraints({ ui.Constraint.Percentage(20), ui.Constraint.Length(7), ui.Constraint.Fill(1) })
		:split(self._area)

	self._area = ui.Layout()
		:direction(ui.Layout.HORIZONTAL)
		:constraints({ ui.Constraint.Percentage(25), ui.Constraint.Percentage(50), ui.Constraint.Percentage(25) })
		:split(rows[2])[2]

	self._chunks = ui.Layout()
		:constraints({
			ui.Constraint.Length(1),
			ui.Constraint.Length(1),
			ui.Constraint.Length(1),
			ui.Constraint.Length(1),
			ui.Constraint.Length(1),
		})
		:split(self._area:pad(ui.Pad(1, 2, 1, 2)))
end

function M:reflow() return { self } end

function M:redraw()
	local s = self.style()

	return {
		ui.Clear(self._area),
		ui.Border(ui.Edge.ALL)
			:area(self._area)
			:set("rounded")
			:style(s.border)
			:title(ui.Line("Compress"):align(ui.Align.CENTER)),

		ui.Text("󰈔 Filename:"):area(self._chunks[1]):style(s.title),
		ui.Fill(self._chunks[2]):style(self.focused == "name" and s.focused or s.unfocused),
		self.name:area(self._chunks[2]:pad(ui.Pad.x(2))):focus(self.focused == "name"),

		ui.Text("󰌾 Password:"):area(self._chunks[4]):style(s.title),
		ui.Fill(self._chunks[5]):style(self.focused == "secret" and s.focused or s.unfocused),
		self.secret:area(self._chunks[5]:pad(ui.Pad.x(2))):focus(self.focused == "secret"),
	}
end

function M:input(name)
	self.name = ui.Input { value = name, hint = "e.g. foo.zip, bar.tar.gz" }
	self.secret = ui.Input { obscure = true, hint = "Optional · ZIP or 7z only" }
	self.focused = "name"
	self.values = { name = name, secret = "" }

	local tx, rx = ya.chan("oneshot")
	local id = Modal:children_add(self, 10)

	local result
	do
		local _ <close> = km.input.rules:insert(1, { on = "<Tab>", run = "app:plugin compress.form" })
		local _ <close> = km.input.rules:insert(1, { on = "<S-Tab>", run = "app:plugin compress.form" })
		local _ <close> = ps.sub("input", function(body)
			if body.type == "cancel" then
				tx:send(false)
			elseif body.type == "submit" then
				self.values[self.focused] = body.value
				tx:send(self.values)
			end
		end)
		render()
		result = rx:recv()
	end

	Modal:children_remove(id)
	render()
	return result
end

function M.style()
	return {
		border = ui.Style():fg("blue"),
		title = ui.Style():fg("green"):bold(),
		focused = th.input.hint:reverse(),
		unfocused = ui.Style(),
	}
end

return M
