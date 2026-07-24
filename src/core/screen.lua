-- screen.lua
-- A simple screen/state stack. Each screen is a table that may implement:
--   :enter(), :leave(), :update(dt), :draw()
-- Only the top screen updates. Draw is top-only unless the top sets
-- `drawBelow = true`, in which case the screen beneath is drawn first (for
-- overlay screens like a pause menu or an inspect popup over the dungeon).

local screen = {}
local stack = {}

function screen.push(s)
    stack[#stack + 1] = s
    if s.enter then s:enter() end
    return s
end

function screen.pop()
    local s = stack[#stack]
    if not s then return end
    if s.leave then s:leave() end
    stack[#stack] = nil
    return s
end

function screen.switch(s)
    while #stack > 0 do screen.pop() end
    return screen.push(s)
end

function screen.current()
    return stack[#stack]
end

function screen.update(dt)
    local top = stack[#stack]
    if top and top.update then top:update(dt) end
end

function screen.draw()
    local top = stack[#stack]
    if not top then return end
    if top.drawBelow then
        local below = stack[#stack - 1]
        if below and below.draw then below:draw() end
    end
    if top.draw then top:draw() end
end

return screen
