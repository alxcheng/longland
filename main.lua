-- Longland — entry point.
-- Wires the core systems together and drives the LOVE callbacks.

local video  = require("src.core.video")
local input  = require("src.core.input")
local screen = require("src.core.screen")
local Title  = require("src.screens.title")

-- Headless helpers (not used in normal play):
--   love . selftest            boot the title, screenshot, quit
--   love . selftest <screen>   boot straight into <screen>, screenshot, quit
--                              (dungeon | encounter | stats | party | equip | item)
--   love . datatest            run the data-model verifier and quit
local selftest = { on = false, frames = 0, shot = nil }

local function bootScreen(name)
    local state = require("src.game.state")
    state.newGame()
    if name == "encounter" then
        screen.push(require("src.screens.encounter").new({ "skeleton", "goblin", "witch" }))
    elseif name == "battlecmd" then
        local enc = require("src.screens.encounter").new({ "skeleton", "goblin", "witch" })
        enc:fastForwardToInput()
        screen.push(enc)
    elseif name == "stats" then
        screen.push(require("src.screens.stats_screen").new())
    elseif name == "party" then
        screen.push(require("src.screens.party_screen").new())
    elseif name == "equip" then
        screen.push(require("src.screens.equip_screen").new())
    elseif name == "item" then
        screen.push(require("src.screens.item_screen").new())
    else
        screen.push(require("src.screens.dungeon").new())
    end
end

function love.load(args)
    args = args or {}
    for i, a in ipairs(args) do
        if a == "selftest" or a == "--selftest" then
            selftest.on = true
            selftest.shot = args[i + 1]
        end
        if a == "datatest" or a == "--datatest" then
            require("src.game.datatest").run()
            love.event.quit()
            return
        end
        if a == "flowtest" or a == "--flowtest" then
            require("src.game.flowtest").run()
            love.event.quit()
            return
        end
        if a == "battletest" or a == "--battletest" then
            require("src.game.battletest").run()
            love.event.quit()
            return
        end
        if a == "screentest" or a == "--screentest" then
            require("src.game.screentest").run()
            love.event.quit()
            return
        end
        if a == "dungeontest" or a == "--dungeontest" then
            require("src.game.dungeontest").run()
            love.event.quit()
            return
        end
    end

    love.keyboard.setKeyRepeat(true)
    video.init()

    if selftest.on and selftest.shot then
        bootScreen(selftest.shot)
    else
        local title = screen.push(Title.new())
        if selftest.on and title.textbox then
            title.textbox:show("The gate to Longland groans open before you.")
        end
    end
end

function love.update(dt)
    screen.update(dt)
    input.endFrame()

    if selftest.on then
        selftest.frames = selftest.frames + 1
        if selftest.frames == 30 then
            love.graphics.captureScreenshot("shot_" .. (selftest.shot or "title") .. ".png")
        end
        if selftest.frames >= 40 then
            local status = video.shaderError
                and ("SELFTEST FAIL: shader error:\n" .. video.shaderError)
                or  "SELFTEST OK: booted, shader compiled, frames rendered."
            love.filesystem.write("selftest.log", status)
            print(status)
            love.event.quit()
        end
    end
end

function love.draw()
    video.beginDraw()
    screen.draw()
    video.endDraw()

    if video.shaderError then
        love.graphics.setColor(1, 0.4, 0.4, 1)
        love.graphics.print("CRT shader failed to compile (see console).", 10, 10)
        love.graphics.setColor(1, 1, 1, 1)
    end
end

function love.keypressed(key, scancode, isrepeat)
    if key == "f11" then
        love.window.setFullscreen(not love.window.getFullscreen())
        video.resize(love.graphics.getDimensions())
        return
    end
    input.keypressed(key, isrepeat)
end

function love.mousepressed(x, y, button)
    input.mousepressed(x, y, button)
end

function love.resize(w, h)
    video.resize(w, h)
end
