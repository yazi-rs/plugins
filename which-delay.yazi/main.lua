--- @since 26.9.1

local reveal = ya.sync(function(st, gen)
	-- A newer key press owns the popup, or the chord ended, or a plugin opened it with `ya.which()`
	if gen ~= st.gen or not cx.which.active or not cx.which.silent or cx.which.tx then
		return
	end

	local opt = cx.which.cands
	opt.layer = tostring(cx.which.layer)
	opt.times = cx.which.times
	opt.silent = false
	ya.emit("which:activate", opt)

	-- Another plugin can keep the event to open nested groups as hidden or shown as their parent
	st.event.silent = false
end)

local function setup(st, opts)
	local timeout = (opts and opts.timeout or 500) / 1000
	st.gen = 0

	ps.sub("ind-which-activate", function(args)
		st.gen, st.event = st.gen + 1, args
		local gen = st.gen

		ya.async(function()
			ya.sleep(timeout)
			reveal(gen)
		end)

		args.silent = true
		return args
	end)
end

return { setup = setup }
