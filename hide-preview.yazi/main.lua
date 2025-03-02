--- @since 25.2.26
--- @sync entry

local function entry(st)
	ya.notify {
		title = "Deprecated plugin",
		content = "The `hide-preview` plugin is deprecated, please use the new `toggle-pane` plugin instead: https://github.com/yazi-rs/plugins/tree/main/toggle-pane.yazi",
		timeout = 10,
		level = "warn",
	}

	if st.old then
		Tab.layout, st.old = st.old, nil
	else
		st.old = Tab.layout
		Tab.layout = function(self)
			local r = rt.mgr.ratio
			self._chunks = ui.Layout()
				:direction(ui.Layout.HORIZONTAL)
				:constraints({
					ui.Constraint.Ratio(r.parent, r.parent + r.current),
					ui.Constraint.Ratio(r.current, r.parent + r.current),
					ui.Constraint.Length(1),
				})
				:split(self._area)
		end
	end
	ya.app_emit("resize", {})
end

local function enabled(st) return st.old ~= nil end

return { entry = entry, enabled = enabled }
