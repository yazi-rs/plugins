local M = {}
local cache = {}

function M:peek(job)
	local skip = job.skip or 0
	local area = job.area
	if not area or not area.w then return end

	local url = tostring(job.file.url)
	local h = area.h
	local fast = job.args and job.args[1] == "--fast"

	if cache.url ~= url then
		cache = { url = url, lines = {}, ansi = false }

		if not fast then
			local path = tostring(job.file.path)
			local output = Command("bat"):arg({
				"--style=numbers",
				"--color=always",
				"--paging=never",
				"--wrap=never",
				"--",
				path,
			}):output()

			if output and output.stdout ~= "" then
				cache.ansi = true
				for line in output.stdout:gmatch("[^\r\n]+") do
					cache.lines[#cache.lines + 1] = line
				end
			end
		end

		if not cache.ansi then
			local f = io.open(tostring(job.file.path), "r")
			if not f then return end
			for line in f:lines() do
				cache.lines[#cache.lines + 1] = line
			end
			f:close()
		end
	end

	if #cache.lines == 0 then return end

	local end_i = math.min(skip + h, #cache.lines)

	if cache.ansi then
		if skip < #cache.lines then
			local visible_raw = table.concat(cache.lines, "\n", skip + 1, end_i)
			ya.preview_widget(job, ui.Text.parse(visible_raw):area(area))
		end
	else
		local visible = {}
		for i = skip + 1, end_i do
			visible[#visible + 1] = ui.Line {
				ui.Span(string.format("%4d ", i)):fg("darkgray"),
				ui.Span(cache.lines[i]),
			}
		end
		ya.preview_widget(job, ui.Text(visible):area(area))
	end
end

function M:seek(job)
	local h = cx.active.current.hovered
	if not h or h.url ~= job.file.url then return end

	local step = math.floor(job.units * job.area.h / 10)
	step = step == 0 and ya.clamp(-1, job.units, 1) or step

	ya.emit("peek", {
		math.max(0, cx.active.preview.skip + step),
		only_if = job.file.url,
	})
end

return M
