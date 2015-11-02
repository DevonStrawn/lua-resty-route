local require = require
local handler = require "resty.route.websocket.handler"
local setmetatable = setmetatable
local setfenv = setfenv
local getfenv = getfenv
local select = select
local ipairs = ipairs
local pairs = pairs
local type = type
local unpack = table.unpack or unpack
local pack = table.pack
local sub = string.sub
local ngx = ngx
local var = ngx.var
local log = ngx.log
local redirect = ngx.redirect
local exit = ngx.exit
local exec = ngx.exec
local log_err = ngx.ERR
local http_ok = ngx.HTTP_OK
local http_error = ngx.HTTP_INTERNAL_SERVER_ERROR
local http_forbidden = ngx.HTTP_FORBIDDEN
local http_not_found = ngx.HTTP_NOT_FOUND
if not pack then
    pack = function(...)
        return { n = select("#", ...), ... }
    end
end
local methods = {
    get       = "GET",
    head      = "HEAD",
    post      = "POST",
    put       = "PUT",
    patch     = "PATCH",
    delete    = "DELETE",
    options   = "OPTIONS",
    link      = "LINK",
    unlink    = "UNLINK",
    trace     = "TRACE",
    websocket = "websocket"
}
local verbs = {}
for k, v in pairs(methods) do
    verbs[v] = k
end
local function tofunction(e, f, m)
    local t = type(f)
    if t == "function" then
        return e and setfenv(f, setmetatable(e, { __index = getfenv(f) })) or f
    elseif t == "table" then
        if m then
            return tofunction(e, f[m])
        else
            return f
        end
    elseif t == "string" then
        return tofunction(e, require(f), m)
    end
    return nil
end
local function websocket(route, location, pattern, self)
    local match = route.matcher
    return (function(...)
        if select(1, ...) then
            return true, handler(self, route, ...)
        end
    end)(match(location, pattern))
end
local function router(route, location, pattern, self)
    local match = route.matcher
    return (function(...)
        if select(1, ...) then
            return true, self(...)
        end
    end)(match(location, pattern))
end
local function filter(route, location, pattern, self)
    if pattern then
        return router(route, location, pattern, self)
    else
        return true, self()
    end
end
local function runfilters(location, method, filters)
    if filters then
        for _, filter in ipairs(filters) do
            filter(location)
        end
        local mfilters = filters[method]
        if mfilters then
            for _, filter in ipairs(mfilters) do
                filter(location)
            end
        end
    end
end
local route = {}
route.__index = route
function route.new(opts)
    local m, t = "simple", type(opts)
    if t == "table" then
        if opts.matcher then m = opts.matcher end
    end
    local self = setmetatable({}, route)
    self.context = { route = self }
    self.context.context = self.context
    if m then
        self:with(m)
    end
    return self
end
function route:use(middleware, ...)
    require("resty.route.middleware." .. middleware)(...)
    return self
end
function route:with(matcher)
    self.matcher = require("resty.route.matchers." .. matcher)
    return self
end
function route:match(location, pattern)
    return self.matcher(location, pattern)
end
function route:filter(pattern, phase)
    local e = self.context
    if not self.filters then
        self.filters = {}
    end
    if not self.filters[phase] then
        self.filters[phase] = {}
    end
    local c = self.filters[phase]
    local t = type(pattern)
    if t == "string" then
        if methods[pattern] then
            if not c[pattern] then
                c[pattern] = {}
            end
            c = c[pattern]
            pattern = nil
        end
        return function(filters)
            if type(filters) == "table" then
                for _, func in ipairs(filters) do
                    local f = tofunction(e, func, phase)
                    c[#c+1] = function(location)
                        return filter(self, location, pattern, f)
                    end
                end
            else
                local f = tofunction(e, filters, phase)
                c[#c+1] = function(location)
                    return filter(self, location, pattern, f)
                end
            end
        end
    elseif t == "table" then
        for _, func in ipairs(pattern) do
            local f = tofunction(e, func, phase)
            c[#c+1] = function(location)
                return filter(self, location, nil, f)
            end
        end
    else
        local f = tofunction(e, pattern, phase)
        c[#c+1] = function(location)
            return filter(self, location, nil, f)
        end
    end
    return self
end
function route:before(pattern)
    return self:filter(pattern, "before")
end
function route:after(pattern)
    return self:filter(pattern, "after")
end
function route:__call(pattern, method, func)
    local e = self.context
    if not self.routes then
        self.routes = {}
    end
    local c = self.routes
    if func then
        if not c[method] then
            c[method] = {}
        end
        local c = c[method]
        local f = tofunction(e, func, method)
        c[#c+1] = function(location)
            return method == "websocket" and websocket(self, location, pattern, f) or router(self, location, pattern, f)
        end
        return self
    else
        return function(routes)
            if type(routes) == "table" then
                if method then
                    if not c[method] then
                        c[method] = {}
                    end
                    local c = c[method]
                    local f = tofunction(e, routes)
                    c[#c+1] = function(location)
                        return method == "websocket" and websocket(self, location, pattern, f) or router(self, location, pattern, f)
                    end
                else
                    for method, func in pairs(routes) do
                        if not c[method] then
                            c[method] = {}
                        end
                        local c = c[method]
                        local f = tofunction(e, func, method)
                        c[#c+1] = function(location)
                            return method == "websocket" and websocket(self, location, pattern, f) or router(self, location, pattern, f)
                        end
                    end
                end
            else
                if not c[method] then
                    c[method] = {}
                end
                local c = c[method]
                local f = tofunction(e, routes, method)
                c[#c+1] = function(location)
                    return method == "websocket" and websocket(self, location, pattern, f) or router(self, location, pattern, f)
                end
            end
            return self
        end
    end
end
for _, v in pairs(verbs) do
    route[v] = function(self, pattern, func)
        return self(pattern, v, func)
    end
end
function route:exit(status, noaf)
    self:terminate(noaf)
    return exit(status)
end
function route:exec(uri, args, noaf)
    self:terminate(noaf)
    return exec(uri, args)
end
function route:redirect(uri, status, noaf)
    self:terminate(noaf)
    return redirect(uri, status)
end
function route:forbidden(noaf)
    route:exit(http_forbidden, noaf)
end
function route:ok(noaf)
    route:exit(http_ok, noaf)
end
function route:error(error, noaf)
    log(log_err, error)
    route:exit(http_error, noaf)
end
function route:notfound(noaf)
    route:exit(http_not_found, noaf)
end
function route:terminate(noaf)
    if not noaf then
        runfilters(self.location, self.method, self.filters and self.filters.after)
    end
end
function route:to(location, method)
    method = method or "get"
    self.location = location
    self.method = method
    local results
    local routes = self.routes
    if routes then
        routes = routes[method]
        if routes then
            for _, route in ipairs(routes) do
                local results = pack(route(location))
                if results.n > 0 then
                    return unpack(results, 1, results.n)
                end
            end
        end
    end
end
function route:dispatch(location, method)
    local location, method = var.uri, verbs[var.http_upgrade == "websocket" and "websocket" or var.request_method]
    runfilters(location, method, self.filters and self.filters.before)
    return self:to(location, method) and self:ok() or self:notfound()
end
return route
