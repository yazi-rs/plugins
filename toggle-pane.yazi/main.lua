--- @since 25.2.26
--- @sync entry

local function entry(st, job)
	local R = rt.mgr.ratio
	job = type(job) == "string" and { args = { job } } or job

	st.parent = st.parent and st.parent or R.parent
	st.current = st.current and st.current or R.current
	st.preview = st.preview and st.preview or R.preview

	st.bf_state.parent  = st.bf_state.parent and st.bf_state.parent  or R.parent
	st.bf_state.current = st.bf_state.current and st.bf_state.current  or R.current
	st.bf_state.preview = st.bf_state.preview and st.bf_state.preview  or R.preview

	local act, to = string.match(job.args[1] or "", "(.-)-(.+)")
	if act == "min" then
		st[to] = st[to] == R[to] and 0 or R[to]
		st.bf_state[to] = st[to]
	elseif act == "max" then
		local max = st[to] == 65535 and st.bf_state[to] or 65535
		st.parent = st.parent == 65535 and st.bf_state.parent or st.parent
		st.current = st.current == 65535 and st.bf_state.current or st.current
		st.preview = st.preview == 65535 and st.bf_state.preview or st.preview
		st[to] = max
	end

	if not st.old then
		st.old = Tab.layout
		Tab.layout = function(self)
			local all = st.parent + st.current + st.preview
			self._chunks = ui.Layout()
				:direction(ui.Layout.HORIZONTAL)
				:constraints({
					ui.Constraint.Ratio(st.parent, all),
					ui.Constraint.Ratio(st.current, all),
					ui.Constraint.Ratio(st.preview, all),
				})
				:split(self._area)
		end
	end

	if not act then
		Tab.layout, st.old = st.old, nil
		st.parent, st.current, st.preview = nil, nil, nil
	end

	ya.app_emit("resize", {})
end

local function setup(st, opts)
	st.bf_state = {}
end

return { setup = setup, entry = entry }
