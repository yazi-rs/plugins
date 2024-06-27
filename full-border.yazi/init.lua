local function setup()
	Manager.render = function(self, area)
		local chunks = self:layout(area)

		local bar = function(c, x, y)
			if x <= 0 or x == area.w - 1 then
				return {}
			end

			return ui.Bar(
				ui.Rect { x = x, y = math.max(0, y), w = ya.clamp(0, area.w - x, 1), h = math.min(1, area.h) },
				ui.Bar.TOP
			):symbol(c)
		end

		return ya.flat {
			-- Borders
			ui.Border(area, ui.Border.ALL):type(ui.Border.ROUNDED),
			ui.Bar(chunks[1]:padding(ui.Padding.y(1)), ui.Bar.RIGHT),
			ui.Bar(chunks[3]:padding(ui.Padding.y(1)), ui.Bar.LEFT),

			bar("┬", chunks[1].right - 1, chunks[1].y),
			bar("┴", chunks[1].right - 1, chunks[1].bottom - 1),
			bar("┬", chunks[2].right, chunks[2].y),
			bar("┴", chunks[2].right, chunks[2].bottom - 1),

			-- Parent
			Parent:render(chunks[1]:padding(ui.Padding.xy(1))),
			-- Current
			Current:render(chunks[2]:padding(chunks[1].w > 0 and ui.Padding.y(1) or ui.Padding(1, 0, 1, 1))),
			-- Preview
			Preview:render(chunks[3]:padding(ui.Padding.xy(1))),
		}
	end
end

return { setup = setup }
