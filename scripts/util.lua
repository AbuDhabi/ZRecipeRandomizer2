local F = {}
F.default_tech_name = "z-randomizer-DEFAULT"
F.item_types = {"item", "ammo", "capsule", "gun", "item-with-entity-data", "selection-tool", "rail-planner", "spidertron-remote", "module", "tool", "armor", "repair-tool"}
F.default_complexity = 5
F.data_missing = "z-randomizer-DATA-MISSING"
F.data_recipes = "z-randomizer-DATA-RECIPES"
F.machines = {"assembling-machine", "rocket-silo", "furnace"}
F.tech_amt = nil


local current_tech = 0
local percentage = 0
function F.get_progress(tech, fraction)
    if tech then
        current_tech = tech
    end
    if fraction then
        percentage = (current_tech + fraction - 1) / F.tech_amt * 100
    end
    return string.format("%.2f",percentage) .. "%"
end

function F.dot(t,n)
    if n == nil then
        if t.string then
            return t.string
        end
        return t.type .. "." .. t.name
    end
    return t .. "." .. n
end

function F.multi_dot(tbl)
    local ret = {}
    for i = 1, #tbl, 1 do
        ret[i] = F.dot(tbl[i])
    end
    return ret
end

function F.dupe_address(tbl)
    return table.concat(F.multi_dot(tbl), ",")
end

return F