-- state.lua
-- Process-wide game state. Screens read state.party rather than threading it
-- through constructors. A real save/load system can serialize this later.

local state = {}

state.party = nil

function state.newGame()
    local db = require("src.game.db")
    state.party = db.startingParty()
    return state.party
end

return state
