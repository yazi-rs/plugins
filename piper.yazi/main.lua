--- @since 25.4.8

local M = {}

local function fail(job, s)
	ya.preview_widgets(job, {
		ui.Text(string.format("`piper` plugin error: %s", s)):area(job.area):wrap(ui.Text.WRAP),
	})
end

function M:peek(job)
	local child, err = Command("sh")
		:args({
			"-c",
			job.args[1],
		})
		:env("w", job.area.w)
		:env("h", job.area.h)
		:args({ "", tostring(job.file.url) })
		:stdout(Command.PIPED)
		:stderr(Command.PIPED)
		:spawn()

	if not child then
		return fail(job, err)
	end

	local limit = job.area.h
	local i, lines = 0, {}
	repeat
		local next, event = child:read_line()
		if event == 1 then
			return fail(job, "error occurred in stderr")
		elseif event ~= 0 then
			break
		end

		i = i + 1
		if i > job.skip then
			lines[#lines + 1] = next
		end
	until i >= job.skip + limit

	child:start_kill()
	if job.skip > 0 and i < job.skip + limit then
		ya.mgr_emit("peek", { math.max(0, i - limit), only_if = job.file.url, upper_bound = true })
	else
		ya.preview_widgets(job, { M.format(job, lines) })
	end
end

function M:seek(job) require("code"):seek(job) end

function M.format(job, lines)
	local format = job.args.format
	if format ~= "url" then
		local s = table.concat(lines, ""):gsub("\t", string.rep(" ", rt.preview.tab_size))
		return ui.Text.parse(s):area(job.area)
	end

	for i = 1, #lines do
		lines[i] = lines[i]:gsub("[\r\n]+$", "")

		local icon = File({
			url = Url(lines[i]),
			cha = Cha { kind = lines[i]:sub(-1) == "/" and 1 or 0 },
		}):icon()

		if icon then
			lines[i] = ui.Line { ui.Span(" " .. icon.text .. " "):style(icon.style), lines[i] }
		end
	end
	return ui.Text(lines):area(job.area)
end

return M
