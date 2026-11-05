local M = {
	suffixes = {
		["7z"] = { "7z" },
		["tar.bz2"] = { "tar", "bzip2" },
		["tar.gz"] = { "tar", "gzip" },
		["tar.xz"] = { "tar", "xz" },
		bz2 = { "bzip2" },
		gz = { "gzip" },
		tar = { "tar" },
		wim = { "wim" },
		xz = { "xz" },
		zip = { "zip" },
	},
}

function M.warn(s, ...)
	ya.notify {
		title = "Compress",
		content = string.format(s, ...),
		level = "warn",
		timeout = 5,
	}
end

function M.steps(name)
	for i in name:gmatch("()%.") do
		local suffix = name:sub(i + 1)
		local steps = M.suffixes[suffix]
		if steps then
			return suffix, steps
		end
	end
end

function M.format(name)
	local _, steps = M.steps(name)
	return steps and steps[1]
end

return M
