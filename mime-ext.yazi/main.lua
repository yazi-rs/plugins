--- @since 26.9.1

local function setup()
	if ya.iter then -- TODO: remove
		for f in rt.plugin.fetchers:match() do
			if f.run.name == "mime.local" then
				rt.plugin.fetchers:update(
					{ id = f.id },
					{ url = "local://*", run = "mime-ext.local", prio = "high", group = "mime" }
				)
			elseif f.run.name == "mime.remote" then
				rt.plugin.fetchers:update(
					{ id = f.id },
					{ url = "remote://*", run = "mime-ext.remote", prio = "high", group = "mime" }
				)
			end
		end
	else
		for i, f in pairs(rt.plugin.fetchers:match()) do
			local _, name = pcall(function() return f.run.name end)
			name = name or f.run

			if name == "mime.local" then
				rt.plugin.fetchers:remove { id = f.id }
				rt.plugin.fetchers:insert(i, { url = "local://*", run = "mime-ext.local", prio = "high", group = "mime" })
			elseif name == "mime.remote" then
				rt.plugin.fetchers:remove { id = f.id }
				rt.plugin.fetchers:insert(i, { url = "remote://*", run = "mime-ext.remote", prio = "high", group = "mime" })
			end
		end
	end
end

return { setup = setup }
