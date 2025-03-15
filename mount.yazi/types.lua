---@class MountDescription
---@field label string
---@field src string source device?
---@field target string | nil mount target
---@field main string | nil main device
---@field sub string | nil sub device
---@field dist string | nil established mount point
---@field fstype string | nil for memes

---@alias DiskAction
---|"eject"
---|"mount"
---|"unmount"

---@alias FsTypes
---|"*"
---|"fuse.sshfs"

---@class FsProvider
---@field get_possible_mounts fun(): table<number, MountDescription> return list of possible mounts ready to be cached
---@field rows fun(entries: MountDescription): table<any> return ui.Rows representation of devices
---@field init nil | fun(): nil -- Perform any additional initialization
---@field mount nil | fun(desc: MountDescription): any, string -- Command output and error if any
---@field unmount  nil |fun(desc: MountDescription): any, string -- Command output and error if any
---@field eject nil | fun(desc: MountDescription): any, string -- Command output and error if any
---@field operate nil | fun(desc: MountDescription, action: DiskAction): any, string -- Command output and error if any
---@field refresh nil | boolean Refresh after running action

---@class PluginState
---@field _id string plugin id
---@field entries table<number, MountDescription> | nil cached filesystem provider entries
---@field fstype FsTypes requested filesystem provider
---@field cursor number cursor position in the view
---@field children number probably id or returned modal actually dont care
