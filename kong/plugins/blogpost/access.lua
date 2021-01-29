local _M = {}
local http = require "resty.http"
local utils = require "kong.tools.utils"

local function error_response(message, status)
    local jsonStr = '{"data":[],"error":{"code":' .. status .. ',"message":"' .. message .. '"}}'
    ngx.header['Content-Type'] = 'application/json'
    ngx.status = status
    ngx.say(jsonStr)
    ngx.exit(status)
end

local function introspect_access_token(conf, access_token, customer_id)
    local httpc = http:new()
    -- step 1: validate the token
    local res, _ = httpc:request_uri(conf.introspection_endpoint, {
        method = "POST",
        ssl_verify = false,
        headers = { ["Content-Type"] = "application/x-www-form-urlencoded",
            ["Authorization"] = "Bearer " .. access_token }
    })

    if not res then
        return { status = 0 }
    end
    if res.status ~= 200 then
        return { status = res.status }
    end

    -- step 2: validate the customer access rights
    local res, _ = httpc:request_uri(conf.authorization_endpoint, {
        method = "POST",
        ssl_verify = false,
        body = '{ "custId":"' .. customer_id .. '"}',
        headers = { ["Content-Type"] = "application/json",
            ["Authorization"] = "Bearer " .. access_token }
    })

    if not res then
        return { status = 0 }
    end
    if res.status ~= 200 then
        return { status = res.status }
    end

    -- ngx.header['new-jwt-kong'] = res.get_headers()["New-Jwt-Token"]
    return { status = res.status, body = res.body }
end

function _M.run(conf)
    local access_token = ngx.req.get_headers()[conf.token_header]
    if not access_token then
        error_response("Unauthenticated.", ngx.HTTP_UNAUTHORIZED)
    end
    -- replace Bearer prefix
    access_token = access_token:sub(8,-1) -- drop "Bearer "
    local request_path = ngx.var.request_uri
    local values = utils.split(request_path, "/")
    local customer_id = values[3]

    local res = introspect_access_token(conf, access_token, customer_id)
    if not res then
        error_response("Authorization server error.", ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    if res.status ~= 200 then
        error_response("The resource owner or authorization server denied the request.", ngx.HTTP_UNAUTHORIZED)
    end

    ngx.req.clear_header(conf.token_header)
end

return _M
