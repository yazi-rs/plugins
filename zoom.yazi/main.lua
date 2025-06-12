--- @since 25.6.11

local get = ya.sync(function(st)
	local h = cx.active.current.hovered
	if not h then
		return
	end

	if st.last ~= h:hash() then
		st.level, st.last = 0, h:hash()
	end

	return {
		url = h.url,
		mime = h:mime() or "",
		level = st.level,
	}
end)

local save = ya.sync(function(st, before, after)
	if st.level == before then
		st.level = after
		return true
	end
end)

local function fail(...) return ya.notify { title = "Zoom", content = string.format(...), timeout = 5, level = "error" } end

local function canvas()
	local cw, ch = rt.term.cell_size()
	if not cw then
		return rt.preview.max_width, rt.preview.max_height
	end

	local area = ui.area("preview")
	return math.min(rt.preview.max_width, math.floor(area.w * cw)),
		math.min(rt.preview.max_height, math.floor(area.h * ch))
end

local function entry(_, job)
	local st = get(job.args[1])
	if not st then
		return
	end

	local info, err = ya.image_info(st.url)
	if not info then
		return fail("Failed to get image info: %s", err)
	end

	local motion = tonumber(job.args[1]) or 0
	local level = ya.clamp(-10, st.level + motion, 10)

	local max_w, max_h = canvas()
	local min_w, min_h = math.min(max_w, info.w), math.min(max_h, info.h)
	local new_w = min_w + math.floor(min_w * level * 0.1)
	local new_h = min_h + math.floor(min_h * level * 0.1)
	if new_w > max_w or new_h > max_h then
		return -- Image larger than available preview area after zooming
	end

	local tmp = os.tmpname()
	-- stylua: ignore
	local status, err = Command("magick"):arg {
		tostring(st.url),
		"-auto-orient", "-strip",
		"-sample", string.format("%dx%d", new_w, new_h),
		"-quality", rt.preview.image_quality,
		string.format("JPG:%s", tmp),
	}:status()

	if not status then
		fail("Failed to run `magick` command: %s", err)
	elseif not status.success then
		fail("`magick` command exited with error code %d", status.code)
	elseif save(st.level, level) then
		ya.image_show(Url(tmp), ui.area("preview"))
	end
end

return { entry = entry }
