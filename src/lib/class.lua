-- Minimal single-inheritance class helper.
--   local Foo = class()
--   function Foo:init(a) self.a = a end
--   local f = Foo.new(1)          -- calls Foo:init(1)
--   local Bar = class(Foo)        -- Bar inherits from Foo
local function class(base)
    local c = {}
    c.__index = c
    if base then
        setmetatable(c, { __index = base })
    end
    function c.new(...)
        local o = setmetatable({}, c)
        if o.init then o:init(...) end
        return o
    end
    return c
end

return class
