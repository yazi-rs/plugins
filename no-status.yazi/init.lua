local function setup()
	local old_layout = Tab.layout

	-- TODO: remove this check once v0.4 is released
	if Status.redraw then
		Status.redraw = function() return {} end
	else
		Status.render = function() return {} end
	end

	Tab.layout = function(self, ...)
		self._area = ui.Rect { x = self._area.x, y = self._area.y, w = self._area.w, h = self._area.h + 1 }
		return old_layout(self, ...)
	end
end

return { setup = setup }
