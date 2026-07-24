-- roll.lua
-- The design doc's "roll": every rolled value lands between 25% below and 25%
-- above the stat. Used for the action-value derived from Speed (1000/speed) and
-- for P/R/M damage/value. Hit / dodge / block ratings are NOT rolled (they're
-- already probabilistic), so they never pass through here.

local roll = {}

-- Uniform in [base*0.75, base*1.25].
function roll.around(base)
    return base * (0.75 + love.math.random() * 0.5)
end

-- Action value from a Speed stat, rolled. Lower AV acts sooner.
function roll.actionValue(speed)
    if speed <= 0 then return math.huge end
    return roll.around(1000 / speed)
end

return roll
