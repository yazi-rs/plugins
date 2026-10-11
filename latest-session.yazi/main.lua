--- @since 26.5.6

local M = {}

local function expand_tilde(path)
  if path == "~" then
    return os.getenv("HOME") or ""
  end

  if path:sub(1, 2) == "~/" then
    return (os.getenv("HOME") or "") .. path:sub(2)
  end

  return path
end

local function state_dir()
  local base = os.getenv("XDG_STATE_HOME")
  if not base or base == "" then
    base = expand_tilde("~/.local/state")
  end

  return base .. "/yazi"
end

local function session_file()
  return state_dir() .. "/latest-session.lua"
end

local function notify(content, level)
  ya.notify {
    title = "latest-session",
    content = content,
    timeout = 5,
    level = level or "info",
  }
end

local function serialize_session(session)
  local lines = {
    "return {",
    string.format("  active_idx = %d,", session.active_idx or 1),
    "  tabs = {",
  }

  for _, tab in ipairs(session.tabs or {}) do
    table.insert(lines, string.format("    { cwd = %q },", tab.cwd))
  end

  table.insert(lines, "  },")
  table.insert(lines, "}")
  table.insert(lines, "")
  return table.concat(lines, "\n")
end

local function is_dir(path)
  if type(path) ~= "string" or path == "" then
    return false
  end

  local ok, cha = pcall(function()
    return fs.cha(Url(path))
  end)

  return ok and cha and cha.is_dir
end

local function load_session()
  local chunk = loadfile(session_file())
  if not chunk then
    return nil
  end

  local ok, session = pcall(chunk)
  if not ok then
    return nil
  end

  return session
end

local function valid_session(session)
  local result = {
    active_idx = 1,
    tabs = {},
  }

  if type(session) ~= "table" or type(session.tabs) ~= "table" then
    return result
  end

  local saved_active_idx = tonumber(session.active_idx) or 1
  for idx, tab in ipairs(session.tabs) do
    if type(tab) == "table" and is_dir(tab.cwd) then
      table.insert(result.tabs, { cwd = tab.cwd })
      if idx <= saved_active_idx then
        result.active_idx = #result.tabs
      end
    end
  end

  return result
end

local read_current_session = ya.sync(function()
  local session = {
    active_idx = cx.tabs.idx,
    tabs = {},
  }

  for _, tab in ipairs(cx.tabs) do
    if tab.current and tab.current.cwd then
      table.insert(session.tabs, {
        cwd = tostring(tab.current.cwd):gsub("\\", "/"),
      })
    end
  end

  if #session.tabs == 0 and cx.active.current.cwd then
    table.insert(session.tabs, {
      cwd = tostring(cx.active.current.cwd):gsub("\\", "/"),
    })
    session.active_idx = 1
  end

  return session
end)

local tab_count = ya.sync(function()
  return #cx.tabs
end)

local restore_session = ya.sync(function(_, session)
  local tabs = session.tabs
  if not tabs or #tabs == 0 then
    return
  end

  ya.emit("cd", { tabs[1].cwd, raw = true })

  for i = 2, #tabs do
    ya.emit("tab_create", { tabs[i].cwd })
  end

  local active_idx = math.max(1, math.min(session.active_idx or 1, #tabs))
  ya.emit("tab_switch", { active_idx - 1 })
end)

function M:save()
  local session = read_current_session()
  if not session or #session.tabs == 0 then
    return false, "No tabs to save"
  end

  local ok, err = fs.create("dir_all", Url(state_dir()))
  if not ok then
    return false, err
  end

  local file
  file, err = io.open(session_file(), "w")
  if not file then
    return false, err
  end

  file:write(serialize_session(session))
  file:close()
  return true
end

function M:restore()
  local session = valid_session(load_session())
  if #session.tabs == 0 then
    return
  end

  restore_session(session)
end

function M:quit()
  local ok, err = self:save()
  if not ok then
    notify("Cannot save tabs: " .. tostring(err), "error")
  end

  ya.emit("quit", {})
end

function M:close()
  if tab_count() <= 1 then
    self:quit()
  else
    ya.emit("close", {})
  end
end

function M:setup()
  self:restore()
end

function M:entry(job)
  local action = job.args[1]

  if action == "save" then
    local ok, err = self:save()
    if not ok then
      notify("Cannot save tabs: " .. tostring(err), "error")
    end
  elseif action == "quit" then
    self:quit()
  elseif action == "close" then
    self:close()
  elseif action == "restore" then
    self:restore()
  end
end

return M
