local _M = { conf = {} }
local http = require "resty.http"
local utils = require "kong.tools.utils"

function _M.error_response(message, status)
    local jsonStr = '{"data":[],"error":{"code":' .. status .. ',"message":"' .. message .. '"}}'
    ngx.header['Content-Type'] = 'application/json'
    ngx.status = status
    ngx.say(jsonStr)
    ngx.exit(status)
end

function _M.introspect_access_token(access_token, customer_id)
    local httpc = http:new()
    -- step 1: validate the token
    local res, _ = httpc:request_uri(_M.conf.introspection_endpoint, {
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
    local res, _ = httpc:request_uri(_M.conf.authorization_endpoint, {
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
    _M.conf = conf
    local access_token = ngx.req.get_headers()[_M.conf.token_header]
    if not access_token then
        _M.error_response("Unauthenticated.", ngx.HTTP_UNAUTHORIZED)
    end
    -- replace Bearer prefix
    access_token = access_token:sub(8,-1) -- drop "Bearer "
    local request_path = ngx.var.request_uri
    local values = utils.split(request_path, "/")
    local customer_id = values[3]

    local res = _M.introspect_access_token(access_token, customer_id)
    if not res then
        _M.error_response("Authorization server error.", ngx.HTTP_INTERNAL_SERVER_ERROR)
    end
    if res.status ~= 200 then
        _M.error_response("The resource owner or authorization server denied the request.", ngx.HTTP_UNAUTHORIZED)
    end

    ngx.req.clear_header(_M.conf.token_header)
end

return _M
