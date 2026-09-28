-- fs.lua
-- Filesystem operations for brace.yazi.
-- Uses Yazi's built-in `fs` API only — no shell, no external processes.
local Fs = {}

-- Create a single directory, including any missing parent directories
-- (equivalent to `mkdir -p`). Returns true on success, or false + error
-- string on failure. Already-existing directories are treated as success.
function Fs.mkdir_p(path)
	local url = Url(path)
	local ok, err = fs.create("dir_all", url)
	if ok then
		return true
	end

	-- If it already exists as a directory, that's not a real failure.
	local cha = fs.cha(url, false)
	if cha and cha.is_dir then
		return true
	end

	return false, tostring(err or "unknown filesystem error")
end

-- Create every directory in `paths` (a list of absolute path strings).
-- Returns two lists: successfully created paths, and { path, error } failures.
function Fs.create_all(paths)
	local created, failed = {}, {}

	for _, path in ipairs(paths) do
		local ok, err = Fs.mkdir_p(path)
		if ok then
			created[#created + 1] = path
		else
			failed[#failed + 1] = { path = path, error = err }
		end
	end

	return created, failed
end

return Fs