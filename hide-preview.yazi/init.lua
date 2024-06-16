local function entry(st)
	if st.old then
		Manager.layout, st.old = st.old, nil
	else
		st.old = Manager.layout
		Manager.layout = function(self, area)
			self.area = area

			local all = MANAGER.ratio.parent + MANAGER.ratio.current
			return ui.Layout()
				:direction(ui.Layout.HORIZONTAL)
				:constraints({
					ui.Constraint.Ratio(MANAGER.ratio.parent, all),
					ui.Constraint.Ratio(MANAGER.ratio.current, all),
					ui.Constraint.Min(1),
				})
				:split(area)
		end
	end
	ya.app_emit("resize", {})
end

return { entry = entry }
