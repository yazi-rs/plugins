--- @sync entry
return {
	entry = function()
		local h = cx.active.current.hovered
		if h and h.cha.is_dir then
			ya.mgr_emit("enter", {})
			ya.mgr_emit("paste", {})
			ya.mgr_emit("leave", {})
		else
			ya.mgr_emit("paste", {})
		end
	end,
}
