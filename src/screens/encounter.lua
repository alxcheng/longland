-- encounter.lua
-- The interactive battle. Renders the party (left) vs enemies (right) with the
-- dummy sprites, and drives the Battle engine's turn loop:
--
--   each frame, while the textbox is idle:
--     1. drain any queued battle messages into the textbox (they gate progress)
--     2. if the battle is over, show the result + leveling, then return to dungeon
--     3. otherwise step the turn machine: beginTurn -> player command / AI / skip
--
-- Player input is a small menu stack in the command panel:
--   root: ACT / GUARD / ITEM / MOVE
--   ACT  -> ability list -> (target list if needed) -> resolve
--   ITEM -> consumable list -> target ally -> use
--   GUARD resolves immediately; MOVE flips row without ending the turn.

local screen  = require("src.core.screen")
local input   = require("src.core.input")
local fonts   = require("src.core.fonts")
local panel   = require("src.ui.panel")
local Menu    = require("src.ui.menu")
local Textbox = require("src.ui.textbox")
local state   = require("src.game.state")
local db      = require("src.game.db")
local sprites = require("src.game.sprites")
local Battle  = require("src.game.battle.battle")

local Encounter = {}
Encounter.__index = Encounter

function Encounter.new(enemyIds)
    local self = setmetatable({}, Encounter)
    self.textbox = Textbox.new()

    local heroes = {}
    for _, u in ipairs(state.party and state.party.deployed or {}) do heroes[#heroes + 1] = u end
    local enemies = db.makeGroup(enemyIds or {})

    self.battle = Battle.new(heroes, enemies)
    self.actors = {}
    self:place(heroes, 1)
    self:place(enemies, -1)

    self.phase = "begin"     -- "begin" | "input" | "over"
    self.cmd = nil           -- active submenu context
    self.menu = nil          -- active Menu
    self.targets = nil       -- units aligned to a target menu (for reticle)
    self.resultShown = false
    self.done = false
    return self
end

-- Fear & Hunger-ish framing: the party sits low and large (near the camera),
-- the enemies higher and smaller (into the scene). Each row is spread
-- horizontally about the centre. side 1 = heroes, side -1 = enemies.
-- `h` is the desired on-screen body height (visible pixels); the sprite's real
-- content height is normalised to it, so mixed packs end up the same apparent
-- size. Heroes are large and low (near the camera); enemies smaller and high.
function Encounter:place(units, side)
    -- Back rows use a wider spacing so they flank out to the sides; front rows
    -- keep the tighter, closer spacing.
    local cfg = (side == 1)
        and { front = { y = 348, h = 150, spacing = 175 }, back = { y = 302, h = 120, spacing = 330 } }
        or  { front = { y = 222, h = 100, spacing = 140 }, back = { y = 186, h = 80,  spacing = 300 } }

    local rows = { front = {}, back = {} }
    for _, u in ipairs(units) do
        local r = (u.row == "back") and "back" or "front"
        rows[r][#rows[r] + 1] = u
    end

    for _, rname in ipairs({ "front", "back" }) do
        local row, n, h = rows[rname], #rows[rname], cfg[rname].h
        for i, u in ipairs(row) do
            local anim = u.sprite and sprites.idle(u.sprite) or nil
            self.actors[u] = {
                anim = anim,
                x = 400 + (i - (n + 1) / 2) * cfg[rname].spacing,
                y = cfg[rname].y,
                h = h,
                scale = anim and (h / anim.contentH) or 1,
                flip = (side == -1),
            }
        end
    end
end

----------------------------------------------------------------- turn loop
function Encounter:update(dt)
    self.textbox:update(dt)
    if self.textbox:isActive() then return end

    if self.battle:hasMessages() then
        if self.autoplay then self.battle:takeMessages()
        else self.textbox:show(self.battle:takeMessages()) end
        return
    end

    if self.battle.over then self:handleOver(); return end

    if self.phase == "input" then
        if self.autoplay then
            self.battle:aiTurn(self.battle.current)
            self:endPlayerTurn()
        else
            self:updateInput(dt)
        end
        return
    end

    -- Non-interactive step.
    local status = self.battle:beginTurn()
    local actor = self.battle.current
    if status == "input" then
        self.phase = "input"
        self:openCommand()
    elseif status == "enemy" then
        self.battle:aiTurn(actor)
        self.battle:endTurn(actor)
    elseif status == "resolved" then
        self.battle:endTurn(actor)
    end
end

function Encounter:handleOver()
    if self.done then return end
    if not self.resultShown then
        self.resultShown = true
        local b = self.battle
        if b.result == "victory" then
            b:log("The party prevails!")
            for _, r in ipairs(b:applyLeveling()) do b:log(r) end
        elseif b.result == "defeat" then
            b:log("The party has fallen...")
        else
            b:log("The battle grinds to a standstill. You withdraw.")
        end
        return -- messages drain first
    end
    self.done = true
    screen.pop()
end

----------------------------------------------------------------- player input
function Encounter:openCommand()
    self.cmd = "root"
    self.targets = nil
    self.menu = Menu.new{
        x = 40, y = 348, fontSize = 16, linePad = 6,
        items = { "ACT", "GUARD", "ITEM", "MOVE" },
        onConfirm = function(item) self:onCommand(item.text) end,
    }
end

function Encounter:onCommand(name)
    local actor = self.battle.current
    if name == "GUARD" then
        self.battle:guard(actor)
        self:endPlayerTurn()
    elseif name == "MOVE" then
        self.battle:move(actor) -- does not end the turn
        self:openCommand()
    elseif name == "ACT" then
        self:openAct()
    elseif name == "ITEM" then
        self:openItem()
    end
end

function Encounter:openAct()
    self.cmd = "act"
    self.targets = nil
    local items = {}
    for _, a in ipairs(self.battle.current:abilities()) do
        if self.battle.current:canUseAbility(a.id) then
            items[#items + 1] = { text = a.def.name, def = a.def, desc = a.def.desc }
        end
    end
    self.menu = Menu.new{
        x = 40, y = 348, fontSize = 15, linePad = 5, items = items,
        onConfirm = function(item) self:chooseAbility(item.def) end,
        onDescribe = function(item) self.textbox:show(item.desc or "No description.") end,
    }
end

function Encounter:chooseAbility(def)
    local actor = self.battle.current
    local err = self.battle:affordError(actor, def)
    if err then self.textbox:show(err); return end

    if def.target == "enemy" then
        self:openTarget(self.battle:livingEnemiesOf(actor), "act", function(t)
            self.battle:performAction(actor, def, t); self:endPlayerTurn()
        end)
    elseif def.target == "ally" then
        self:openTarget(self.battle:livingAllies(actor), "act", function(t)
            self.battle:performAction(actor, def, t); self:endPlayerTurn()
        end)
    else -- self / allAllies / allEnemies: no target selection
        self.battle:performAction(actor, def, nil)
        self:endPlayerTurn()
    end
end

function Encounter:openItem()
    self.cmd = "item"
    self.targets = nil
    local items = {}
    for _, it in ipairs(state.party:itemsOfSlot("consumable")) do
        items[#items + 1] = { text = it.name, item = it, desc = it.desc }
    end
    self.menu = Menu.new{
        x = 40, y = 348, fontSize = 15, linePad = 5, items = items,
        onConfirm = function(item) self:chooseItem(item.item) end,
        onDescribe = function(item) self.textbox:show(item.desc or "No description.") end,
    }
end

function Encounter:chooseItem(item)
    self:openTarget(self.battle:livingAllies(self.battle.current), "item", function(t)
        if item.use and item.use.resource == "mp" then t:healMP(item.use.amount)
        elseif item.use then t:healHP(item.use.amount) end
        state.party:removeItem(item)
        self.battle:log(string.format("%s uses %s. (+%d %s)", t.name, item.name,
            item.use.amount, string.upper(item.use.resource)))
        self:endPlayerTurn()
    end)
end

function Encounter:openTarget(list, returnTo, onPick)
    self.cmd = "target"
    self.targetReturn = returnTo
    self.targets = list
    self.onPick = onPick
    local items = {}
    for i, u in ipairs(list) do items[i] = { text = u.name, unit = u } end
    self.menu = Menu.new{
        x = 40, y = 348, fontSize = 15, linePad = 5, items = items,
        onConfirm = function(item) self.onPick(item.unit) end,
    }
end

function Encounter:updateInput(dt)
    self.menu:update(dt)
    if input.pressed("cancel") then
        if self.cmd == "act" or self.cmd == "item" then
            self:openCommand()
        elseif self.cmd == "target" then
            if self.targetReturn == "act" then self:openAct() else self:openItem() end
        end
        -- root: cannot cancel out of your own turn
    end
end

function Encounter:endPlayerTurn()
    self.battle:endTurn(self.battle.current)
    self.phase = "begin"
    self.menu, self.cmd, self.targets = nil, nil, nil
end

-- Test helper: advance (discarding messages, AI-ing enemies) until it's a hero's
-- turn, so a screenshot can show the command panel. Returns true if it landed on
-- an input turn.
function Encounter:fastForwardToInput(maxSteps)
    for _ = 1, (maxSteps or 2000) do
        if self.battle:hasMessages() then
            self.battle:takeMessages()
        elseif self.battle.over then
            return false
        elseif self.phase == "input" then
            return true
        else
            local status = self.battle:beginTurn()
            local actor = self.battle.current
            if status == "input" then
                self.phase = "input"; self:openCommand()
            elseif status == "enemy" then
                self.battle:aiTurn(actor); self.battle:endTurn(actor)
            elseif status == "resolved" then
                self.battle:endTurn(actor)
            end
        end
    end
    return false
end

----------------------------------------------------------------- drawing
local function marker(x, y, r, g, b)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.polygon("fill", x, y, x - 7, y - 12, x + 7, y - 12)
    love.graphics.setColor(1, 1, 1, 1)
end

-- A simple one-point-perspective room, in the same wireframe spirit as the
-- dungeon crawler view: back wall + corner diagonals + a couple of floor lines.
local function drawArena()
    love.graphics.setColor(0.26, 0.44, 0.34, 1)
    love.graphics.setLineWidth(1)
    local bx, by, bw2, bh = 300, 54, 200, 150
    love.graphics.rectangle("line", bx, by, bw2, bh)
    love.graphics.line(0, 0, bx, by)
    love.graphics.line(800, 0, bx + bw2, by)
    love.graphics.line(0, 450, bx, by + bh)
    love.graphics.line(800, 450, bx + bw2, by + bh)
    for _, t in ipairs({ 0.33, 0.66 }) do
        local y = (by + bh) + t * (450 - (by + bh))
        local lx = bx * (1 - t)
        local rx = (bx + bw2) + t * (800 - (bx + bw2))
        love.graphics.line(lx, y, rx, y)
    end
    love.graphics.setColor(1, 1, 1, 1)
end

function Encounter:draw()
    love.graphics.clear(0, 0, 0, 1)
    drawArena()

    -- Which unit is the current target reticle over?
    local reticleUnit
    if self.cmd == "target" and self.targets then
        reticleUnit = self.targets[self.menu.index]
    end

    local order = {}
    for u, a in pairs(self.actors) do order[#order + 1] = { u = u, a = a } end
    table.sort(order, function(p, q) return p.a.y < q.a.y end)
    for _, p in ipairs(order) do
        local u, a = p.u, p.a
        love.graphics.setColor(1, 1, 1, u.alive and 1 or 0.25)
        if a.anim then
            a.anim:draw(a.x, a.y, a.scale, a.flip)
        else
            love.graphics.rectangle("line", a.x - 16, a.y - 48, 32, 48)
        end

        if u == self.battle.current and self.phase == "input" then
            marker(a.x, a.y - a.h - 10, 0.9, 0.9, 0.5)  -- yellow: acting
        end
        if u == reticleUnit then
            marker(a.x, a.y - a.h - 10, 0.9, 0.4, 0.4)  -- red: targeting
        end
    end

    -- Command panel (title reflects context).
    local title = "COMMAND"
    if self.phase == "input" and self.battle.current then
        if self.cmd == "act" then title = self.battle.current.name .. "  ->  ACT"
        elseif self.cmd == "item" then title = self.battle.current.name .. "  ->  ITEM"
        elseif self.cmd == "target" then title = "Choose a target"
        else title = self.battle.current.name .. "'s turn" end
    end
    panel.titled(16, 312, 200, 126, title)
    if self.menu then self.menu:draw() end

    -- Enemy status.
    local ry = panel.titled(232, 312, 552, 126, "ENEMIES")
    love.graphics.setFont(fonts.get(13))
    for i, u in ipairs(self.battle.enemies) do
        local x = 246 + ((i - 1) % 2) * 268
        local y = ry + math.floor((i - 1) / 2) * 28
        love.graphics.setColor(1, 1, 1, u.alive and 1 or 0.35)
        love.graphics.print(string.format("%s   HP %s", u.name, u:hpString()), x, y)
    end
    love.graphics.setColor(1, 1, 1, 1)

    self.textbox:draw()
end

return Encounter
