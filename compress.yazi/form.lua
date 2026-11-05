--- @sync entry

local common = require(".common")

local render = ya.sync(ui.render)

local M = {}

function M:new(area)
	local me = setmetatable({ _area = area }, { __index = self })
	me:layout()
	return me
end

function M:entry(job)
	self:update(cx.input.alt.value)
	if job.args[1] == "toggle" then
		self.values[job.args[2]] = not self.values[job.args[2]]
		return ui.render()
	end

	local fields = self:fields()
	local n = job.args[1] == "reverse" and -1 or 1
	repeat
		self.focused = (self.focused - 1 + n) % #fields + 1
	until fields[self.focused].h > 0 and fields[self.focused].kind == "input"
	ui.render()
end

function M:layout()
	local fields, constraints = self:fields(), {}
	for _, field in ipairs(fields) do
		constraints[#constraints + 1] = ui.Constraint.Length(field.gap + field.h)
	end

	local rows = ui.Layout()
		:constraints({ ui.Constraint.Percentage(20), ui.Constraint.Length(fields.sum + 2), ui.Constraint.Fill(1) })
		:split(self._area)

	self._area = ui.Layout()
		:direction(ui.Layout.HORIZONTAL)
		:constraints({ ui.Constraint.Percentage(25), ui.Constraint.Percentage(50), ui.Constraint.Percentage(25) })
		:split(rows[2])[2]

	self._chunks = ui.Layout():constraints(constraints):split(self._area:pad(ui.Pad(1, 2, 1, 2)))
end

function M:reflow() return { self } end

function M:redraw()
	local s = self.style()

	local widgets = {
		ui.Clear(self._area),
		ui.Border(ui.Edge.ALL)
			:area(self._area)
			:set("rounded")
			:style(s.border)
			:title(ui.Line("Compress"):align(ui.Align.CENTER)),
	}

	for i, field in ipairs(self:fields()) do
		if field.h > 0 then
			local draw = self["draw_" .. field.kind]
			local area = self._chunks[i]:pad(ui.Pad.top(field.gap))
			widgets = ya.list_merge(widgets, draw(self, field, area, self.focused == i, s))
		end
	end

	return widgets
end

function M:draw_input(field, area, focused, style)
	local rows = ui.Layout():constraints({ ui.Constraint.Length(1), ui.Constraint.Fill(1) }):split(area)
	return {
		ui.Text(field[2]):area(rows[1]):style(style.title),
		ui.Fill(rows[2]):style(focused and style.focused or style.unfocused),
		self[field[1]]:area(rows[2]:pad(ui.Pad.x(2))):focus(focused),
	}
end

function M:draw_toggle(field, area, _, style)
	local checked = self.values[field[1]]
	local label = string.format("%s %s · %s", checked and "󰗠" or "󰄰", field[2], field.key)
	return { ui.Text(label):area(area):style(checked and style.checked or style.unchecked) }
end

function M:input(name)
	self.name = ui.Input { value = name, realtime = true, hint = "e.g. foo.zip, bar.tar.gz" }
	self.secret = ui.Input { obscure = true, realtime = true, hint = "Optional" }
	self.confirm = ui.Input { obscure = true, hint = "Repeat password" }
	self.focused = 1
	self.values = { name = name, secret = "", confirm = "", encrypt_header = false }

	local tx, rx = ya.chan("oneshot")
	local id = Modal:children_add(self, 10)

	local result
	do
		local _ <close> = km.input.rules:insert(1, { on = "<Tab>", run = "app:plugin compress.form" })
		local _ <close> = km.input.rules:insert(1, { on = "<S-Tab>", run = "app:plugin compress.form reverse" })
		local _ <close> =
			km.input.rules:insert(1, { on = "<C-h>", run = "app:plugin compress.form -- toggle encrypt_header" })
		local _ <close> = ps.sub("input", function(body)
			if body.type == "type" then
				self:update(body.value)
				ui.render()
			elseif body.type == "cancel" then
				tx:send(false)
			elseif body.type == "submit" then
				self:update(body.value)
				local values = self:validate()
				if values then
					tx:send(values)
				end
			end
		end)
		render()
		result = rx:recv()
	end

	Modal:children_remove(id)
	render()
	return result
end

function M:fields()
	local v = self.values
	local f = common.format(v.name)
	local pwd = f == "7z" or f == "zip"

	local fields = {
		{ "name", "󰈔 Filename:", kind = "input", h = 2 },
		{ "secret", "󰌾 Password:", kind = "input", h = pwd and 2 or 0 },
		{ "confirm", "󰌾 Confirm password:", kind = "input", h = pwd and v.secret ~= "" and 2 or 0 },
		{
			"encrypt_header",
			"Encrypt filenames",
			kind = "toggle",
			key = "<C-h>",
			h = f == "7z" and v.secret ~= "" and 1 or 0,
		},
		sum = 0,
	}

	for i, field in ipairs(fields) do
		field.gap = i > 1 and field.h > 0 and 1 or 0
		fields.sum = fields.sum + field.gap + field.h
	end
	return fields
end

function M.style()
	return {
		border = ui.Style():fg("blue"),
		title = ui.Style():fg("green"):bold(),
		focused = th.input.hint:reverse():italic(true),
		unfocused = ui.Style(),
		checked = ui.Style():fg("green"),
		unchecked = th.input.hint,
	}
end

function M:update(value) self.values[self:fields()[self.focused][1]] = value end

function M:validate()
	local name = fs.safename(self.values.name)
	local suffix, steps = common.steps(name or "")
	local format = steps and steps[1]
	local secret = (format == "7z" or format == "zip") and self.values.secret or ""

	if self.values.name == "" then
		return common.warn("Filename cannot be empty")
	elseif not name then
		return common.warn("Invalid archive filename")
	elseif not steps then
		return common.warn("Unsupported archive filename: %s", name)
	elseif secret ~= "" and secret ~= self.values.confirm then
		return common.warn("Passwords do not match")
	else
		return {
			name = name,
			suffix = suffix,
			steps = steps,
			secret = secret,
			encrypt_header = format == "7z" and secret ~= "" and self.values.encrypt_header,
		}
	end
end

return M
