--- @since 25.5.31
--- @sync entry
return {
	entry = function(_, job)
		local h = cx.active.current.hovered
		local is_forced = job.args and job.args[1] == "force" 

		if h and h.cha.is_dir then
			ya.emit("enter", {})
			ya.emit("paste", { force = is_forced })
			ya.emit("leave", {})
		else
			ya.emit("paste", { force = is_forced })
		end
	end,
}
