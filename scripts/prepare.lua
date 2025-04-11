local random = require "scripts.random"
local resource_util = require "scripts.resource_util"
local util = require "scripts.util"

local do_hidden = settings.startup["z-randomizer-hidden"].value

local F = {}

function F.recipes()
    local recipes = {}

    -- POPULATE RECIPES FROM FACTORIO DATA
    for recipe_name, recipe_definition in pairs(data.raw.recipe) do
        local original = nil
        if recipe_definition.normal then
            original = table.deepcopy(recipe_definition.normal)
        elseif recipe_definition.expensive then
            original = table.deepcopy(recipe_definition.expensive)
        else
            original = table.deepcopy(recipe_definition)
        end
        if do_hidden ~= "ignore" or (not recipe_definition.hidden and not original.hidden) then
            local recipe = {}
            if original.enabled == nil or original.enabled == "true" then
                recipe.enabled = true
            else
                recipe.enabled = original.enabled
            end
            if original.results then
                recipe.res = original.results
            elseif original.result then
                recipe.res = {{original.result, original.result_count or 1}}
            end

            recipe.time = original.energy_required or recipe_definition.energy_required
            recipe.category = original.category or recipe_definition.category
            recipe.hidden = original.hidden or recipe_definition.hidden
            recipe.name = recipe_name
            if recipe.res and original.ingredients then
                recipe.ing = original.ingredients
                recipes[recipe_name] = recipe
            end
        end
    end

    -- ADD ROCKET LAUNCH PRODUCTS AND SPENT FUEL
    for i = 1, #util.item_types, 1 do
        for name, item in pairs(data.raw[util.item_types[i]]) do
            if item.rocket_launch_products then
                recipes[name .. "#rocket-launch"] = {name = name .. "#rocket-launch", enabled = true, time = 5, ing = {{name, 1}, {"rocket-part", 100}}, res = item.rocket_launch_products}
            elseif item.rocket_launch_product then
                recipes[name .. "#rocket-launch"] = {name = name .. "#rocket-launch", enabled = true, time = 5, ing = {{name, 1}, {"rocket-part", 100}}, res = {item.rocket_launch_product}}
            end
            if item.burnt_result then
                recipes[name .. "#burning"] = {name = name .. "#burning", enabled = true, time = 1, ing = {{name, 1}}, res = {{item.burnt_result, 1}}}
            end
        end
    end

    -- ADD SEABLOCK HARDCODED RESEARCH
    if mods["SeaBlockMetaPack"] then
        recipes["ore3#sb-research"] = {name = "ore3#sb-research", enabled = true, time = 1, ing = {{"angels-ore3-crushed", 1}}, res = {{"sb-angelsore3-tool", 1}}}
        recipes["algae#sb-research"] = {name = "algae#sb-research", enabled = true, time = 1, ing = {{"algae-brown", 1}}, res = {{"sb-algae-brown-tool", 1}}}
        recipes["circuit#sb-research"] = {name = "ore3#sb-research", enabled = true, time = 1, ing = {{"basic-circuit-board", 1}}, res = {{"sb-basic-circuit-board-tool", 1}}}
        recipes["lab#sb-research"] = {name = "lab3#sb-research", enabled = true, time = 1, ing = {{"lab", 1}}, res = {{"sb-lab-tool", 1}}}
    end

    -- UNIFY FORMAT
    local rocket_launch = {}

    for recipe_name, recipe in pairs(recipes) do
        for i, _ in pairs(recipe.ing) do
            if recipe.ing[i][1] and recipe.ing[i][2] then
                recipe.ing[i].type = "item"
                recipe.ing[i].name = recipe.ing[i][1]
                recipe.ing[i].amount = recipe.ing[i][2]
                recipe.ing[i][1] = nil
                recipe.ing[i][2] = nil
            elseif recipe.ing[i][1] then
                recipe.ing[i].type = "item"
                recipe.ing[i].name = recipe.ing[i][1]
                recipe.ing[i].amount = 1
                recipe.ing[i][1] = nil
            elseif not recipe.ing[i].type then
                recipe.ing[i].type = "item"
            end
        end

        for i, _ in pairs(recipe.res) do
            if recipe.res[i][1] and recipe.res[i][2] then
                recipe.res[i].type = "item"
                recipe.res[i].name = recipe.res[i][1]
                recipe.res[i].amount = recipe.res[i][2]
                recipe.res[i][1] = nil
                recipe.res[i][2] = nil
            elseif recipe.res[i][1] then
                recipe.res[i].type = "item"
                recipe.res[i].name = recipe.res[i][1]
                recipe.res[i].amount = 1
                recipe.res[i][1] = nil
            elseif not recipe.res[i].type then
                recipe.res[i].type = "item"
            end
            if recipe.res[i].amount_min then
                recipe.res[i].amount = math.max(recipe.res[i].amount_min, (recipe.res[i].amount_min + recipe.res[i].amount_max) / 2)
            end
            if recipe.res[i].probability then
                recipe.res[i].amount = recipe.res[i].amount * math.max(math.min(recipe.res[i].probability, 1), 0)
            end
            if recipe.res[i].multiplier then
                recipe.res[i].amount = recipe.res[i].amount * recipe.res[i].multiplier
            end
        end

        for i, _ in pairs(recipe.res) do
            for j, _ in pairs(recipe.res) do
                if i < j and recipe.res[i].type == recipe.res[j].type and recipe.res[i].name == recipe.res[j].name then
                    recipe.res[i].amount = recipe.res[i].amount + recipe.res[j].amount
                    recipe.res[j] = nil
                end
            end
        end

        -- CLEAN UP MISSING PROPERTIES
        for i, _ in pairs(recipe.res) do
            if recipe.res[i].amount == 0 then
                recipe.res[i] = nil
            end
        end
        local new_res = {}
        for _, value in pairs(recipe.res) do
            new_res[#new_res + 1] = value
        end
        recipe.res = new_res

        for i, _ in pairs(recipe.ing) do
            if recipe.ing[i].amount == 0 then
                recipe.ing[i] = nil
            end
        end
        local new_ing = {}
        for _, value in pairs(recipe.ing) do
            new_ing[#new_ing + 1] = value
        end
        recipe.ing = new_ing

        if recipe.time == nil then
            recipe.time = 0.5
        end

        if recipe.category == nil then
            recipe.category = "crafting"
        end

        if string.match(recipe_name, "#rocket%-launch") then
            local ingredient = util.dot(recipe.ing[1])
            for _, res in pairs(recipe.res) do
                rocket_launch[ingredient] = util.dot(res)
            end
        end

        -- ENABLE RANDOMIZATION OF CLIFF EXPLOSIVES
        if recipe_name == "cliff-explosives" then
            for key, value in pairs(recipe.ing) do
                if value.name == "empty-barrel" then
                    value.name = "steel-plate"
                    recipe.ing[key] = value
                end
            end
        end

        recipes[recipe_name] = recipe
    end

    return recipes, rocket_launch
end

function F.filter_recipes(recipes)
    local categories = {}
    local forbidden_categories = settings.startup["z-randomizer-forbidden-categories"].value
    for value in string.gmatch(forbidden_categories, "([%a%d%-_:]+)") do
        categories[value] = true
    end
    for recipe_name, recipe in pairs(recipes) do
        if categories[recipe.category] then
            recipes[recipe_name] = nil
        end
    end

    for value in string.gmatch(settings.startup["z-randomizer-forbidden-recipes"].value, "%[recipe=([%a%d%-_:]+)%]") do
        recipes[value] = nil
    end

    local f_ings = settings.startup["z-randomizer-forbidden-ingredients"].value .. " [item=mining-drone] [item=transport-drone]"
    for u, v in string.gmatch(f_ings, "%[(%a+)=([%a%d%-_:]+)%]") do
        for n, r in pairs(recipes) do
            for _, i in pairs(r.ing) do
                if i.type == u and i.name == v then
                    recipes[n] = nil
                    break
                end
            end
        end
    end

    for u, v in string.gmatch(settings.startup["z-randomizer-forbidden-results"].value, "%[(%a+)=([%a%d%-_:]+)%]") do
        for n, r in pairs(recipes) do
            for _, i in pairs(r.res) do
                if i.type == u and i.name == v then
                    recipes[n] = nil
                    break
                end
            end
        end
    end

    for n, r in pairs(recipes) do
        for _, value in pairs(r.ing) do
            if value.type == "fluid" then
                if data.raw.fluid[value.name].hidden then
                    recipes[n] = nil
                    break
                end
            else
                for _, it in ipairs(util.item_types) do
                    if data.raw[it][value.name] and data.raw[it][value.name].hidden then
                        recipes[n] = nil
                        break
                    end
                end
            end
            if not recipes[n] then
                break
            end
        end
    end

    return recipes
end

function F.remove_unresearchable(recipes, tech)
    local allowed = {}
    for _, t in pairs(tech) do
        for _, r in pairs(t.recipes) do
            allowed[r] = true
        end
    end
    for n, r in pairs(recipes) do
        if not allowed[n] then
            recipes[n] = nil
        end
    end
    return recipes
end

function F.default_values(recipes)
    local ret = {}
    for p, r, v in string.gmatch(string.gsub(settings.startup["z-randomizer-default-values"].value, "%s+", ""), "%(([%a%d%-%*%[%]=_]*):([%a%d%-%*%[%]=_]+):(%d*%.*%d+)%)") do
        local tech = nil
        local items = nil
        for t, n in string.gmatch(p, "%[(%a+)=([%a%d%-_:]+)%]") do
            if t == "technology" then
                tech = n
                break
            else
                if not items then
                    items = {}
                end
                items[#items + 1] = util.dot(t, n)
            end
        end
        local total = {tech = tech, value = tonumber(v)}
        if not tech then
            total["items"] = items
        end
        for t, n in string.gmatch(r, "%[(%a+)=([%a%d%-_:]+)%]") do
            ret[util.dot(t, n)] = total
        end
    end

    -- ADD NON-RANDOMIZABLE
    for t, n in string.gmatch(settings.startup["z-randomizer-not-random-resources"].value, "%[(%a+)=([%a%d%-_:]+)%]") do
        ret[util.dot(t, n)] = {value = math.huge}
    end

    local new_ret = {}
    for _, r in pairs(recipes) do
        for _, v in pairs(r.ing) do
            local n = util.dot(v)
            new_ret[n] = ret[n]
        end
        for _, v in pairs(r.res) do
            local n = util.dot(v)
            new_ret[n] = ret[n]
        end
    end

    return new_ret
end

function F.duplicate_prevention(dont_randomize, recipes)
    local ret = {}
    for v in string.gmatch(settings.startup["z-randomizer-prevent-duplicates"].value, "([%a%d%-_:]+)") do
        ret[v] = {}
    end
    for i = 1, #dont_randomize, 1 do
        local r = recipes[dont_randomize[i]]
        if ret[r.category] ~= nil then
            ret[r.category][util.dupe_address(r.ing)] = dont_randomize[i]
        end
    end
    return ret
end

function F.tech(recipes, rocket_launch)
    local tech = {}
    local science = {}

    local default_tech = {pre = {}, recipes = {}, science = {}, allowed = {[util.default_tech_name] = true}}
    for n, r in pairs(recipes) do
        if r.enabled == true or r.enabled == "true" then
            default_tech.recipes[#default_tech.recipes + 1] = n
        end
    end
    tech[util.default_tech_name] = default_tech

    for n, t in pairs(data.raw.technology) do
        local original = nil
        if t.normal then
            original = t.normal
        elseif t.expensive then
            original = t.expensive
        else
            original = t
        end
        if (original.hidden == nil or not original.hidden) and (original.enabled == nil or original.enabled) then
            local nt = {pre = {util.default_tech_name}, recipes = {}, science = {}, allowed = {[n] = true}}
            if original.prerequisites then
                nt.pre = table.deepcopy(original.prerequisites)
            end
            if original.unit ~= nil and original.unit.ingredients ~= nil then
                for _, value in pairs(original.unit.ingredients) do
                    local item
                    if #value == 2 then
                        item = util.dot("item", value[1])
                    elseif value.name and not value.type then
                        item = util.dot("item", value.name)
                    else
                        item = util.dot(value)
                    end
                    if not science[item] then
                        science[item] = true
                    end
                    nt.science[item] = value.amount or value[2]
                end
            end
            if original.effects ~= nil then
                for _, e in pairs(original.effects) do
                    if e.type == "unlock-recipe" and recipes[e.recipe] ~= nil then
                        nt.recipes[#nt.recipes + 1] = e.recipe
                    end
                end
            end
            tech[n] = nt
        end
    end

    for n, t in pairs(tech) do
        for _, r in pairs(t.recipes) do
            if not string.match(r, "#") then
                for _, res in pairs(recipes[r].res) do
                    local name = util.dot(res)
                    if res.type == "item" and science[name] then
                        science[name] = n
                    end
                    if rocket_launch[name] and science[rocket_launch[name]] then
                        science[rocket_launch[name]] = n
                    end
                end
            end
        end
    end

    for n, t in pairs(tech) do
        for s, v in pairs(t.science) do
            if v ~= true and science[s] ~= true then
                t.pre[#t.pre + 1] = science[s]
            end
        end
    end

    log("Science found: " .. serpent.line(science))

    return tech, science
end

function F.categories(recipes)
    local def_cats = {}
    local item_cats = {}
    local all_cats = {}
    local unlockable_cats = {}
    for category in string.gmatch(settings.startup["z-randomizer-starter-crafting"].value, "([%a%d%-_:]+)") do
        def_cats[category] = {[util.default_tech_name] = true}
    end
    if data.raw.character.character and data.raw.character.character.crafting_categories then
        for _, category in pairs(data.raw.character.character.crafting_categories) do
            def_cats[category] = {[util.default_tech_name] = true}
        end
    end

    for _, r in pairs(recipes) do
        all_cats[r.category] = true

        for _, ing in pairs(r.ing) do
            if ing.type == "item" then
                local item = util.dot(ing)
                local place
                for i = 1, #util.item_types, 1 do
                    if data.raw[util.item_types[i]][ing.name] then
                        place = data.raw[util.item_types[i]][ing.name].place_result
                        break
                    end
                end
                if place ~= nil then
                    for _, mt in ipairs(util.machines) do
                        local machine = data.raw[mt][place]
                        if machine ~= nil and machine.crafting_categories ~= nil then
                            for _, cat in pairs(machine.crafting_categories) do
                                if not item_cats[item] then
                                    item_cats[item] = {}
                                end
                                item_cats[item][#item_cats[item] + 1] = cat
                                unlockable_cats[cat] = true
                            end
                        end
                    end
                end
            end
        end
        for _, res in pairs(r.res) do
            if res.type == "item" then
                local item = util.dot(res)
                local place
                for i = 1, #util.item_types, 1 do
                    if data.raw[util.item_types[i]][res.name] then
                        place = data.raw[util.item_types[i]][res.name].place_result
                        break
                    end
                end
                if place ~= nil then
                    for _, mt in ipairs(util.machines) do
                        local machine = data.raw[mt][place]
                        if machine ~= nil and machine.crafting_categories ~= nil then
                            for _, cat in pairs(machine.crafting_categories) do
                                if not item_cats[item] then
                                    item_cats[item] = {}
                                end
                                item_cats[item][#item_cats[item] + 1] = cat
                                unlockable_cats[cat] = true
                            end
                        end
                    end
                end
            end
        end
    end
    for cat, _ in pairs(all_cats) do
        if not unlockable_cats[cat] then
            log("MISSING DEFAULT CRAFTING CATEGORY: " .. cat)
            def_cats[cat] = {[util.default_tech_name] = true}
        end
    end
    return def_cats, item_cats
end

function F.unstackable()
    local u = {}
    for i = 1, #util.item_types, 1 do
        for name, item in pairs(data.raw[util.item_types[i]]) do
            if item.stack_size == 1 then
                u["item." .. name] = true
            end
        end
    end
    return u
end

function F.get_ingredients_and_recipe_not_to_randomize(recipes)
    local rec = {}
    local cats = {}
    local ing = {}

    for v in string.gmatch(settings.startup["z-randomizer-not-random-recipes"].value .. " [recipe=fuel-processing]", "%[recipe=([%a%d%-_:]+)%]") do
        rec[v] = true
    end

    for v in string.gmatch(settings.startup["z-randomizer-not-random-categories"].value, "([%a%d%-_:]+)") do
        cats[v] = true
    end
    for v, r in pairs(recipes) do
        if cats[r.category] or string.match(v, "#") or (do_hidden ~= "randomize" and r.hidden) then
            rec[v] = true
        end
    end
    for t, n in string.gmatch(settings.startup["z-randomizer-not-random-ingredients"].value, "%[(%a+)=([%a%d%-_:]+)%]") do
        ing[util.dot(t, n)] = true
    end

    return rec, ing
end

function F.amounts(old_resources, new_resources, changeable, ings, min_value, max_value, max_raw, min_time, max_time, resource_variance, unstackable)
    if ings == nil then
        return
    end
    local target_value = random.float_range(min_value, max_value)
    local raw_left = resource_util.multiply(max_raw, math.min(target_value * 1.1 / max_value, 1))
    raw_left.time = max_time
    raw_left.complexity = nil
    raw_left.value = max_raw.value
    local raws = {}
    for _, i in ipairs(changeable) do
        raws[i] = table.deepcopy(new_resources.raw(ings[i].string))
        raws[i].complexity = nil
        if raws[i].time == nil then
            raws[i].time = 1
        end
    end
    local units = {}
    for _, i in ipairs(changeable) do
        local s = 15625
        local max_amt = max_value / raws[i].value
        for key, value in pairs(raws[i]) do
            if key ~= "value" and key ~= "time" and key ~= "complexity" and raw_left[key] then
                local m = raw_left[key] / value
                if m < max_amt then
                    max_amt = m
                end
            end
        end
        max_amt = max_amt / 4 / #changeable
        local min_amt = ings[i].type == "item" and 1 or 0.1
        while s >= max_amt do
            s = s * 0.2
            if s * 0.2 < min_amt then
                s = min_amt
                break
            end
        end
        units[i] = s
    end
    local sum = {time = 0}
    for _, i in ipairs(changeable) do
        raws[i] = resource_util.multiply(raws[i], units[i])
        sum = resource_util.add(sum, raws[i])
    end

    local achievable = {}
    for key, _ in pairs(sum) do
        achievable[key] = raw_left[key]
    end
    achievable = old_resources.recalculate_value(achievable).value
    if achievable < min_value then
        return
    end

    local amts = table.deepcopy(units)
    while true do
        local fits = {}
        local fits_sum = 0
        if sum.value > target_value then
            break
        end
        local left = resource_util.subtract(raw_left, sum)
        for c, i in ipairs(changeable) do
            local f
            if not unstackable[ings[i].string] and amts[i] < 50000 then
                f = resource_util.fits_amt(raws[i], left)
            else
                f = 0
            end
            fits[c] = f
            fits_sum = fits_sum + f
        end
        if fits_sum == 0 then
            break
        end
        local r = random.range(1, fits_sum)
        local c = 0
        while r > 0 do
            c = c + 1
            r = r - fits[c]
        end
        local i = changeable[c]
        amts[i] = amts[i] + units[i]
        sum = resource_util.add(sum, raws[i])
        if amts[i] >= 19.5 * units[i] then
            raws[i] = resource_util.multiply(raws[i], 5)
            units[i] = 5 * units[i]
        end
    end
    if sum.value >= min_value and sum.value <= max_value and sum.time > min_time and sum.time <= max_time then
        local ret = {}
        for _, i in ipairs(changeable) do
            ret[i] = {type = ings[i].type, name = string.match(ings[i].string, "[%a%d%-_:]+$"), amount = amts[i]}
        end
        for i, ing in ipairs(ings) do
            if not ret[i] then
                ret[i] = {type = ing.type, name = ing.name, amount = ing.amount}
            end
        end
        return ret
    end
    return
end

function F.final_recipe(new_recipe, old_recipe)
    local final = nil
    if old_recipe.normal then
        final = old_recipe.normal
    elseif old_recipe.expensive then
        final = old_recipe.expensive
    else
        final = table.deepcopy(old_recipe)
    end
    final.type = "recipe"
    final.name = old_recipe.name
    final.category = old_recipe.category
    final.subgroup = old_recipe.subgroup
    final.icons = old_recipe.icons
    final.icon = old_recipe.icon
    final.icon_size = old_recipe.icon_size
    final.crafting_machine_tint = old_recipe.crafting_machine_tint
    for i, ing in ipairs(final.ingredients) do
        if ing.fluidbox_index ~= nil then
            new_recipe.ing[i].fluidbox_index = ing.fluidbox_index
        end
    end
    final.ingredients = table.deepcopy(new_recipe.ing)
    final.energy_required = new_recipe.time
    return final
end

return F
