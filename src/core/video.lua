-- video.lua
-- Fixed 800x450 (16:9) internal resolution. Everything draws into an off-screen
-- canvas at that size; the canvas is then letterboxed into the window (limited by
-- the shorter dimension, black bars on the longer one) and run through the CRT
-- shader. Every screen goes through here, so the CRT is applied globally.

local crtSource = require("src.core.crt_shader")

local video = {}

video.GAME_W = 800
video.GAME_H = 450

local canvas
local shader
video.shaderError = nil

-- The rectangle (in window pixels) the game is drawn into.
local target = { x = 0, y = 0, w = video.GAME_W, h = video.GAME_H, scale = 1 }

function video.init()
    canvas = love.graphics.newCanvas(video.GAME_W, video.GAME_H)
    canvas:setFilter("linear", "linear")

    local ok, result = pcall(love.graphics.newShader, crtSource)
    if ok then
        shader = result
        video.shaderError = nil
    else
        shader = nil
        video.shaderError = tostring(result)
        print("[video] CRT shader failed to compile:\n" .. video.shaderError)
    end

    video.resize(love.graphics.getDimensions())
end

-- Recompute the letterbox rectangle for a given window size.
function video.resize(w, h)
    local targetAspect = video.GAME_W / video.GAME_H
    local windowAspect = w / h
    local scale
    if windowAspect > targetAspect then
        -- Window too wide: limited by height, pillarbox left/right.
        scale = h / video.GAME_H
    else
        -- Window too tall/narrow: limited by width, letterbox top/bottom.
        scale = w / video.GAME_W
    end
    local dw = video.GAME_W * scale
    local dh = video.GAME_H * scale
    target.x = math.floor((w - dw) / 2 + 0.5)
    target.y = math.floor((h - dh) / 2 + 0.5)
    target.w = dw
    target.h = dh
    target.scale = scale
end

-- Begin drawing the game frame (into the internal canvas).
function video.beginDraw()
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
end

-- Finish the game frame: present the canvas to the window through the CRT shader.
function video.endDraw()
    love.graphics.setCanvas()
    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)

    if shader then
        love.graphics.setShader(shader)
        -- Guard sends: an unused uniform gets stripped by the GLSL compiler, and
        -- sending to a stripped uniform is a hard error.
        local function send(name, value)
            if shader:hasUniform(name) then shader:send(name, value) end
        end
        send("source", canvas)
        send("trg_x", target.x)
        send("trg_y", target.y)
        send("trg_w", target.w)
        send("trg_h", target.h)
    end

    love.graphics.draw(canvas, target.x, target.y, 0, target.scale, target.scale)
    love.graphics.setShader()
end

-- Convert a window-space point (e.g. mouse) into game-space coordinates.
function video.toGame(px, py)
    return (px - target.x) / target.scale, (py - target.y) / target.scale
end

return video
