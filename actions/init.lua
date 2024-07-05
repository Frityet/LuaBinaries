---@class Action
---@field name string
---@field description string
---@field configure_command fun(cmd: argparse.Command)
---@field action fun(args: BaseArguments): integer

---@type Action[]
return {
    get_lua = require("actions.get-lua")
}
