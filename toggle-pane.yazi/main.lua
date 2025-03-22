--- @since 25.2.26
--- @sync entry

local function entry(st, job)
	local R = rt.mgr.ratio
	local rs = st.reset_state and st.reset_state or R
	job = type(job) == "string" and { args = { job } } or job

	st.parent = st.parent or R.parent
	st.current = st.current or R.current
	st.preview = st.preview or R.preview

	local act, to = string.match(job.args[1] or "", "(.-)-(.+)")
	if act == "min" then
		st[to] = st[to] == R[to] and 0 or R[to]
	elseif act == "max" then
		local max = st[to] == 65535 and R[to] or 65535
		st.parent = st.parent == 65535 and rs.parent or st.parent
		st.current = st.current == 65535 and rs.current or st.current
		st.preview = st.preview == 65535 and rs.preview or st.preview
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
	st.reset_state = opts.reset_state
end

return { setup = setup, entry = entry }
