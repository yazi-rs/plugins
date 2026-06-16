--- @since 26.1.22

local root = ya.sync(function() return cx.active.current.cwd end)

local function fail(content) return ya.notify { title = "VCS Files", content = content, timeout = 5, level = "error" } end

local function entry()
	local root = root()

	local diff_output, diff_err = Command("git"):cwd(tostring(root)):arg({ "diff", "--name-only", "HEAD" }):output()
	if diff_err then
		return fail("Failed to run `git diff`, error: " .. diff_err)
	elseif not diff_output.status.success then
		return fail("Failed to run `git diff`, stderr: " .. diff_output.stderr)
	end

	local untracked_output, untracked_err = Command("git"):cwd(tostring(root)):arg({ "ls-files", "--others", "--exclude-standard" }):output()
	if untracked_err then
		return fail("Failed to run `git ls-files`, error: " .. untracked_err)
	elseif not untracked_output.status.success then
		return fail("Failed to run `git ls-files`, stderr: " .. untracked_output.stderr)
	end

	local id = ya.id("ft")
	local cwd = root:into_search("Git changes")
	ya.emit("cd", { Url(cwd), source = "search" })
	ya.emit("update_files", { op = fs.op("part", { id = id, url = Url(cwd), files = {} }) })

	local files = {}
	local seen = {}
	for line in (diff_output.stdout .. untracked_output.stdout):gmatch("[^\r\n]+") do
		if seen[line] then goto continue end
		seen[line] = true
		local url = cwd:join(line)
		local cha = fs.cha(url, true)
		if cha then
			files[#files + 1] = File { url = url, cha = cha }
		end
		::continue::
	end
	ya.emit("update_files", { op = fs.op("part", { id = id, url = Url(cwd), files = files }) })
	ya.emit("update_files", { op = fs.op("done", { id = id, url = cwd, cha = Cha { mode = tonumber("100644", 8) } }) })
end

return { entry = entry }
