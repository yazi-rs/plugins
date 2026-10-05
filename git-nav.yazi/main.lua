--- @sync entry

local function notify(msg)
  ya.notify({
    title = "Git",
    content = msg,
    timeout = 3,
  })
end

local function git(cwd, args)
  local tmpfile = os.tmpname()
  local cmd = string.format("cd '%s' && git %s > '%s' 2>/dev/null", cwd, table.concat(args, " "), tmpfile)

  os.execute(cmd)

  local f = io.open(tmpfile, "r")
  if not f then
    os.remove(tmpfile)
    return nil
  end

  local out = f:read("*a")
  f:close()
  os.remove(tmpfile)

  out = out and out:gsub("%s+$", "") or ""

  if out == "" then
    return nil
  end

  return out
end

local function get_changed_files(root)
  local out = git(root, { "status", "--porcelain" })
  if not out then
    return {}
  end

  local files = {}
  for line in out:gmatch("[^\n]+") do
    -- git status --porcelain format: XY filename
    -- Skip first 3 chars (status + space)
    local file = line:sub(4)
    -- Handle renamed files (old -> new)
    file = file:match("-> (.+)") or file
    -- Remove quotes if present
    file = file:gsub('^"', ''):gsub('"$', '')
    if file ~= "" then
      table.insert(files, root .. "/" .. file)
    end
  end

  table.sort(files)
  return files
end

local function navigate_changed(cwd, direction)
  local root = git(cwd, { "rev-parse", "--show-toplevel" })
  if not root then
    notify("Not inside a git repository")
    return
  end

  local files = get_changed_files(root)
  if #files == 0 then
    notify("No changed files")
    return
  end

  -- Get current hovered file
  local hovered = cx.active.current.hovered
  local current_path = hovered and tostring(hovered.url.path) or cwd

  -- Find current position in list
  local current_idx = 0
  for i, file in ipairs(files) do
    if file == current_path or current_path:find(file, 1, true) then
      current_idx = i
      break
    end
  end

  -- Calculate next index
  local next_idx
  if direction == "next" then
    next_idx = current_idx + 1
    if next_idx > #files then
      next_idx = 1 -- wrap around
    end
  else -- prev
    next_idx = current_idx - 1
    if next_idx < 1 then
      next_idx = #files -- wrap around
    end
  end

  local target = files[next_idx]
  ya.emit("reveal", { target })
end

local function entry(self, job)
  local args = job.args or {}
  local action = args[1]
  local cwd = tostring(cx.active.current.cwd.path)

  local path = nil

  if action == "root" then
    path = git(cwd, { "rev-parse", "--show-toplevel" })

  elseif action == "super" then
    path = git(cwd, { "rev-parse", "--show-superproject-working-tree" })
        or git(cwd, { "rev-parse", "--show-toplevel" })

  elseif action == "gitdir" then
    path = git(cwd, { "rev-parse", "--git-common-dir" })

  elseif action == "lazygit" then
    if not git(cwd, { "rev-parse", "--is-inside-work-tree" }) then
      notify("Not inside a git repository")
      return
    end
    ya.emit("shell", { "lazygit", block = true })
    return

  elseif action == "next" then
    navigate_changed(cwd, "next")
    return

  elseif action == "prev" then
    navigate_changed(cwd, "prev")
    return
  end

  if not path then
    notify("Not inside a git repository")
    return
  end

  ya.emit("cd", { path })
end

return { entry = entry }
