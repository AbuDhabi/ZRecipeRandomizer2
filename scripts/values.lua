local F = {}
F.default_tech_name = "z-randomizer-DEFAULT"
F.item_types = {"item", "ammo", "capsule", "gun", "item-with-entity-data", "item-with-label", "item-with-inventory", "item-with-tags", "selection-tool", "rail-planner", "spidertron-remote", "module", "tool", "armor", "repair-tool"}
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
return F