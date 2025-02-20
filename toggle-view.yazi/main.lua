--- @since 25.2.7
--- @sync entry

local function entry(st, job)
	local R = MANAGER.ratio
	st.parent = st.parent and st.parent or R.parent
	st.current = st.current and st.current or R.current
	st.preview = st.preview and st.preview or R.preview

	local act = type(job) == "string" and job or job.args[1]
	if act == "min-parent" then
		st.parent = st.parent == R.parent and 0 or R.parent
	elseif act == "min-current" then
		st.current = st.current == R.current and 0 or R.current
	elseif act == "min-preview" then
		st.preview = st.preview == R.preview and 0 or R.preview
	elseif act == "max-parent" then
		st.parent = st.parent == 65535 and R.parent or 65535
	elseif act == "max-current" then
		st.current = st.current == 65535 and R.current or 65535
	elseif act == "max-preview" then
		st.preview = st.preview == 65535 and R.preview or 65535
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

	if act == "reset" then
		Tab.layout, st.old = st.old, nil
		st.parent, st.current, st.preview = nil, nil, nil
	end

	ya.app_emit("resize", {})
end

return { entry = entry }
