---@class Options
---@field order number The order in which the status is displayed
---@field renamed boolean Whether to include renamed files in the status (or treat them as modified)

---@alias Changes table<string, CODES>

---@class State
---@field dirs table<string, string|CODES> Mapping between a directory and its corresponding repository
---@field repos table<string, Changes> Mapping between a repository and the status of each of its files
