local M = {}

function M:peek()
	local child, code = Command("lsar"):arg(tostring(self.file.url)):stdout(Command.PIPED):spawn()
	if not child then
		return ya.err("spawn `lsar` command returns " .. tostring(code))
	end

	-- Skip the first line which is the archive file itself
	while true do
		local _, event = child:read_line()
		if event == 0 or event ~= 1 then
			break
		end
	end

	local limit = self.area.h
	local i, lines = 0, {}
	repeat
		local next, event = child:read_line()
		if event ~= 0 then
			break
		end

		i = i + 1
		if i > self.skip then
			lines[#lines + 1] = ui.Line(next)
		end
	until i >= self.skip + limit

	child:start_kill()
	if self.skip > 0 and i < self.skip + limit then
		ya.manager_emit("peek", { math.max(0, i - limit), only_if = self.file.url, upper_bound = true })
	else
		ya.preview_widgets(self, { ui.Paragraph(self.area, lines) })
	end
end

function M:seek(units)
	local h = cx.active.current.hovered
	if h and h.url == self.file.url then
		local step = math.floor(units * self.area.h / 10)
		ya.manager_emit("peek", {
			math.max(0, cx.active.preview.skip + step),
			only_if = self.file.url,
		})
	end
end

return M
