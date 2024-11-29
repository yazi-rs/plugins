local M = {}

function M:peek(job)
	-- TODO: remove this once Yazi 0.4 is released
	job = job or self

	local child, code = Command("lsar"):arg(tostring(job.file.url)):stdout(Command.PIPED):spawn()
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

	local limit = job.area.h
	local i, lines = 0, {}
	repeat
		local next, event = child:read_line()
		if event ~= 0 then
			break
		end

		i = i + 1
		if i > job.skip then
			lines[#lines + 1] = next
		end
	until i >= job.skip + limit

	child:start_kill()
	if job.skip > 0 and i < job.skip + limit then
		ya.manager_emit("peek", { math.max(0, i - limit), only_if = job.file.url, upper_bound = true })
	else
		ya.preview_widgets(job, { ui.Text(lines):area(job.area) })
	end
end

function M:seek(job)
	-- TODO: remove this once Yazi 0.4 is released
	local units = type(job) == "table" and job.units or job
	job = type(job) == "table" and job or self

	local h = cx.active.current.hovered
	if h and h.url == job.file.url then
		local step = math.floor(units * job.area.h / 10)
		ya.manager_emit("peek", {
			math.max(0, cx.active.preview.skip + step),
			only_if = job.file.url,
		})
	end
end

return M
