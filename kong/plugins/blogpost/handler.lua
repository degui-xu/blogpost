local access = require "kong.plugins.custom-auth.access"

local TokenHandler = {
    VERSION = "1.0",
    PRIORITY = 1000,
}

function TokenHandler:access(conf)
    access.run(conf)
end

return TokenHandler
