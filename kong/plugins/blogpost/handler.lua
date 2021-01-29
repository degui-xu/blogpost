local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.custom-auth.access"

local TokenHandler = BasePlugin:extend()

function TokenHandler:new()
    TokenHandler.super.new(self, "custom-auth")
end

function TokenHandler:access(conf)
    TokenHandler.super.access(self)
    access.run(conf)
end

TokenHandler.VERSION = "1.0"
TokenHandler.PRIORITY = 1000

return TokenHandler
