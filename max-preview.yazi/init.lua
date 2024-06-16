local function entry(st)
	if st.old then
		Manager.layout, st.old = st.old, nil
	else
		st.old = Manager.layout
		Manager.layout = function(self, area)
			self.area = area

			return ui.Layout()
				:direction(ui.Layout.HORIZONTAL)
				:constraints({
					ui.Constraint.Percentage(0),
					ui.Constraint.Percentage(0),
					ui.Constraint.Percentage(100),
				})
				:split(area)
		end
	end
	ya.app_emit("resize", {})
end

return { entry = entry }
