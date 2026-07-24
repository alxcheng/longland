-- title.lua
-- Demo screen that ties the foundation together: Menu (arrow selector + describe)
-- and Textbox, all rendered inside the 800x450 canvas through the CRT shader.
-- Serves as a live smoke test for the reusable pieces until real screens land.

local Menu = require("src.ui.menu")
local Textbox = require("src.ui.textbox")
local fonts = require("src.core.fonts")
local screen = require("src.core.screen")
local state = require("src.game.state")
local Dungeon = require("src.screens.dungeon")

local Title = {}
Title.__index = Title

function Title.new()
    local self = setmetatable({}, Title)
    self.textbox = Textbox.new()

    self.menu = Menu.new{
        x = 300,
        y = 250,
        items = {
            { text = "New Game", desc = "Begin a new descent into Longland." },
            { text = "Continue", desc = "No description." },
            { text = "Quit",     desc = "Leave this place. For now." },
        },
        onConfirm = function(item)
            if item.text == "Quit" then
                love.event.quit()
            elseif item.text == "New Game" then
                state.newGame()
                screen.switch(Dungeon.new())
            else
                self.textbox:show("No saved journey yet, traveler.")
            end
        end,
        onDescribe = function(item)
            self.textbox:show(item.desc or "No description.")
        end,
    }
    return self
end

function Title:update(dt)
    -- Textbox captures input while it's up; otherwise the menu is live.
    if self.textbox:isActive() then
        self.textbox:update(dt)
    else
        self.menu:update(dt)
    end
end

function Title:draw()
    -- Title wordmark.
    love.graphics.setFont(fonts.get(52))
    love.graphics.setColor(0.86, 0.87, 0.66, 1)
    love.graphics.print("LONGLAND", 300, 120)

    love.graphics.setFont(fonts.get(12))
    love.graphics.setColor(0.6, 0.6, 0.6, 1)
    love.graphics.print("arrows/wasd move   .   enter/space select   .   q describe", 300, 200)

    self.menu:draw()
    self.textbox:draw()
    love.graphics.setColor(1, 1, 1, 1)
end

return Title
