-- input.lua
-- Abstracts raw keys/mouse into named actions. Directions repeat while held (for
-- menu scrolling); confirm/cancel/describe fire once per press. Edges are recorded
-- by the love.keypressed/mousepressed callbacks and cleared at the end of each
-- frame via input.endFrame().

local input = {}

local bindings = {
    up      = { "up", "w" },
    down    = { "down", "s" },
    left    = { "left", "a" },
    right   = { "right", "d" },
    confirm = { "return", "kpenter", "space" },
    cancel  = { "escape", "backspace" },
    describe = { "q" },
}

-- key -> action lookup
local keyToAction = {}
for action, keys in pairs(bindings) do
    for _, k in ipairs(keys) do
        keyToAction[k] = action
    end
end

-- Which actions are allowed to fire on key-repeat.
local repeatable = { up = true, down = true, left = true, right = true }

local pressed = {}                       -- action -> true if it fired this frame
local mouseState = { clicked = false, x = 0, y = 0 }

function input.keypressed(key, isrepeat)
    local action = keyToAction[key]
    if not action then return end
    if isrepeat and not repeatable[action] then return end
    pressed[action] = true
end

function input.mousepressed(x, y, button)
    if button == 1 then
        mouseState.clicked = true
        mouseState.x, mouseState.y = x, y
        pressed.confirm = true           -- a click advances / confirms
    end
end

-- True if the action fired this frame.
function input.pressed(action)
    return pressed[action] == true
end

-- True if physically held right now (polled straight from LOVE).
function input.down(action)
    local keys = bindings[action]
    if not keys then return false end
    for _, k in ipairs(keys) do
        if love.keyboard.isDown(k) then return true end
    end
    return false
end

function input.mouseClicked()
    return mouseState.clicked, mouseState.x, mouseState.y
end

-- Clear per-frame edges. Call once at the end of love.update.
function input.endFrame()
    for k in pairs(pressed) do pressed[k] = nil end
    mouseState.clicked = false
end

return input
