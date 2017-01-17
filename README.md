# lua-resty-route

**lua-resty-route** is a URL routing library for OpenResty supporting
pluggable route matchers.

## Matchers

`lua-resty-route` supports multiple different matchers on routing. Right now
we support these:

* Prefix (case-sensitive and case-insensitive)
* Equals (case-sensitive and case-insensitive)
* Match (using Lua's `string.match` function)
* Regex (case-sensitive and case-insensitive)
* Simple (case-sensitive and case-insensitive)

Matcher is selected by a prefix in a route's pattern, and they do somewhat
follow the Nginx's `location` block prefixes:

Prefix | Matcher | Case-sensitive
-------|---------|---------------
`[none]` | Prefix | ✓
`*` | Prefix | 
`=` | Equals | ✓
`=*` | Equals | 
`#` | Match | ¹
`~` | Regex | ✓
`~*` | Regex | 
`@` | Simple | ✓
`@*` | Simple | 

¹ Lua `string.match` can be case-sensitive or case-insensitive.

## Routing

There are many different ways to define routes in `lua-resty-template`.
It can be said that it is somewhat a Lua DSL for defining routes.

To define routes, you first need a new instance of route. This instance
can be shared with different requests. You may create the routes in
`init_by_lua*`. Here we define a new route instance:

```lua
local route = require "resty.route".new()
```

Now that we do have this `route` instance, we may continue to a next
section, [HTTP Routing](#http-routing).

### HTTP Routing

HTTP routing is a most common thing to do in web related routing. That's
why HTTP routing is the default way to route in `lua-resty-route`. Other
types of routing include e.g. [WebSockets routing](#websockets-routing).

The most common HTTP request methods (sometimes referred to as verbs) are:

Method | Definition
-------|-----------
`GET` | Read
`POST` | Create
`PUT` | Update or Replace
`PATCH` | Update or Modify
`DELETE` | Delete

While these are the most common ones, `lua-resty-route` is not by any means
restricted to these. You may use whatever request methods there is just like
these common ones. But to keep things simple here, we will just use these in
the examples.

**The general pattern in routing is this:**

```lua
route(method, [[pattern], func])
```

**e.g.:**

```lua
route("get", "/", function(self) end)
```

**or with `method` defined in a method call we can use this:**

```lua
route:[method](pattern, [func])
```

**e.g.:**

```lua
route:get("/", function(self) end)
```

Now only the first parameter is mandatory. That's why we
can call these functions in a quite flexible ways. Next we
look at different ways to call these functions.

**Defining routes as a table:**

```lua
route "=/users" {
    get  = function(self) end,
    post = function(self) end
}
```

**or:**

```lua
local users = {
    get  = function(self) end,
    post = function(self) end
}
route "=/users" (users)
-- that is same as:
route("=/users", users)
```

**or even (`string` funcs are `require`d automatically):**

```lua
route "=/users" "controllers.users"
-- that is same as:
route("=/users", "controllers.users")
```

**NOTE:** be careful with this as all the callable string keys in that
table will be used as a route handlers (aka this may lead to unwanted
exposure of a code that you don't want to be called on HTTP requests).

**Routing all HTTP request methods:**

```lua
route "/" (function(self) end)
-- that is same as:
route("/", function(self) end)
```

### WebSockets Routing

### Dispatching

## Status Handlers

## Middleware

## License

`lua-resty-route` uses two clause BSD license.

```
Copyright (c) 2015 – 2017, Aapo Talvensaari
All rights reserved.

Redistribution and use in source and binary forms, with or without modification,
are permitted provided that the following conditions are met:

* Redistributions of source code must retain the above copyright notice, this
  list of conditions and the following disclaimer.

* Redistributions in binary form must reproduce the above copyright notice, this
  list of conditions and the following disclaimer in the documentation and/or
  other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES`
