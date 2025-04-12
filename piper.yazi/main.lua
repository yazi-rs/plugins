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
	local i, lines = 0, ""
	repeat
		local next, event = child:read_line()
		if event == 1 then
			return fail(job, "error occurred in stderr")
		elseif event ~= 0 then
			break
		end

		i = i + 1
		if i > job.skip then
			lines = lines .. next
		end
	until i >= job.skip + limit

	child:start_kill()
	if job.skip > 0 and i < job.skip + limit then
		ya.mgr_emit("peek", { math.max(0, i - limit), only_if = job.file.url, upper_bound = true })
	else
		lines = lines:gsub("\t", string.rep(" ", rt.preview.tab_size))
		ya.preview_widgets(job, {
			ui.Text.parse(lines):area(job.area),
		})
	end
end

function M:seek(job) require("code"):seek(job) end

return M
