-- require('__debugadapter__/debugadapter.lua')
local bigpack = require "__big-data-string2__.pack"

-- PREPARE HELPERS
local resource_util = require "scripts.resource_util"
local random = require "scripts.random"
random.seed(settings.startup["z-randomizer-seed"].value)
local prepare = require "scripts.prepare"
local search = require "scripts.search"
local resources = require "scripts.resources"
local missing_check = require "scripts.missing_check"
local util = require "scripts.util"

-- PREPARE SETTINGS
local resource_variance = math.exp(settings.startup["z-randomizer-resource-variance"].value - 2) * 0.3
local complexity_variance = math.exp(settings.startup["z-randomizer-complexity-variance"].value - 2) * 0.7
local value_variance = math.exp(settings.startup["z-randomizer-cost-variance"].value - 2) * 0.3
local time_variance = settings.startup["z-randomizer-randomize-time"].value
if time_variance == "small" then
    time_variance = 2
elseif time_variance == "medium" then
    time_variance = 2.5
elseif time_variance == "large" then
    time_variance = 4
elseif time_variance == "huge" then
    time_variance = 8
else
    time_variance = 1.5
end
local dependencies = settings.startup["z-randomizer-dependencies"].value
local hidden = settings.startup["z-randomizer-hidden"].value

-- PREPARE TABLES
local recipes, rocket_launch = prepare.recipes()
recipes = prepare.filter_recipes(recipes)
local tech, science = prepare.tech(recipes, rocket_launch)
recipes = prepare.remove_unresearchable(recipes, tech)
local default_values = prepare.default_values(recipes)
local missing = missing_check.resources(recipes, default_values)

if not missing then
    log("PREPARING RECIPES...")
    local recipes_not_to_randomize, ingredients_not_to_randomize = prepare.get_ingredients_and_recipe_not_to_randomize(recipes)
    local dupe = prepare.duplicate_prevention(recipes_not_to_randomize, recipes)
    local default_categories, category_unlocks = prepare.categories(recipes)
    local unstackable = prepare.unstackable()

    local old_resources = resources.new()
	old_resources.init(default_values, default_categories, category_unlocks, ingredients_not_to_randomize, recipes)
    local new_resources = resources.new()
	new_resources.init(default_values, default_categories, category_unlocks)

    log("PREPARATION DONE!")

    -- RANDOMIZE
    local function randomize(recipe_name, technologies_allowed, pattern)
        log("  " .. util.get_progress() .. "                Recipe: " .. recipe_name)
        local recipe = recipes[recipe_name]

        if not pattern then
            pattern = old_resources.pattern(recipe_name)
        end

        if not pattern or #pattern.changeable == 0 then
            if dupe[recipe.category] then
                local dupe_address = util.dupe_address(recipe.ing)
                dupe[recipe.category][dupe_address] = recipe_name
            end
            log("  " .. util.get_progress() .. "                     (nothing to change)")
            return table.deepcopy(recipe)
        end

        local vv, cv, tv, rv = value_variance, complexity_variance, time_variance, resource_variance

        local nt = random.time(recipe.time)

        local cycles, total_tries, tries = 0, 0, 0

        while true do
            local pre_raw = resource_util.add(resource_util.multiply(old_resources.base_raw, rv * pattern.raw.value / #pattern.changeable), pattern.raw)
            pre_raw.value = pattern.raw.value
            local min_value, max_value = pattern.raw.value / (1 + vv), pattern.raw.value * (1 + vv)
            local min_time, max_time = pattern.raw.time / (1 + 2 * tv), pattern.raw.time * (1 + tv)

            local max_raw = resource_util.multiply(pre_raw, max_value / pattern.raw.value)

            for ings in search.ingredient_combinations(old_resources, new_resources, pattern.pattern, pattern.changeable, recipe, max_raw, max_value, cv, ingredients_not_to_randomize, dependencies == "branched", technologies_allowed) do
                tries = tries + 1
                total_tries = total_tries + 1
                if dupe[recipe.category] then
                    local dupe_address = util.dupe_address(ings)
                    if dupe[recipe.category][dupe_address] then
                        ings = nil
                    end
                end
				-- pass recipe name so we can detect scrap-recycling
                ings = prepare.amounts(old_resources, new_resources, pattern.changeable, ings, min_value, max_value, max_raw, min_time, max_time, resource_variance, unstackable, recipe_name)
                if ings then
                    local nr = table.deepcopy(recipe)
                    nr.ing = ings
                    nr.time = nt

                    if dupe[recipe.category] then
                        local dupe_address = util.dupe_address(ings)
                        dupe[recipe.category][dupe_address] = recipe_name
                    end

                    log(" " .. util.get_progress() .. "                     (cycles: " .. cycles .. " tries: " .. total_tries .. ")")
                    return nr
                end
                if tries >= 1500 / (#pattern.changeable + 1) then
                    break
                end
            end
            tries = 0
            cycles = cycles + 1
            vv = vv * 1.2
            cv = cv * 1.4
            rv = rv * 1.6
            tv = tv * 1.8
            if #pattern.changeable > 1 then
                local selected = random.int(#pattern.changeable)
                local to_change = pattern.changeable[selected]
                pattern.changeable[selected] = pattern.changeable[#pattern.changeable]
                pattern.changeable[#pattern.changeable] = nil
                pattern.pattern[to_change].name = pattern.pattern[to_change].on
                pattern.pattern[to_change].amount = pattern.pattern[to_change].oa
                pattern.raw = resource_util.subtract(pattern.raw, pattern.raws[to_change])
            else
                if dupe[recipe.category] then
                    local dupe_address = util.dupe_address(recipe.ing)
                    dupe[recipe.category][dupe_address] = recipe_name
                end
                log(" " .. util.get_progress() .. "                     (gave up after " .. cycles .. " cycles)")
                return table.deepcopy(recipe)
            end
        end
    end

    local randomized = {}
    local waiting_for_category = {}
    -- RANDOMIZE BASED ON SELECTED SETTING
    if dependencies ~= "none" then
        for technology_name, technology in search.tech(tech, true) do
            local amt = #technology.recipes
            random.shuffle(technology.recipes)
            for recipe_index, recipe_name in ipairs(technology.recipes) do
                log(" " .. util.get_progress(nil, (recipe_index - 1) / amt) .. "          Step: " .. recipe_index .. "/" .. amt)
                -- CALCULATE RESOURCES
                if recipes[recipe_name] then
                    local to_randomize = old_resources.calculate(recipes[recipe_name], technology_name, technology.allowed, technology.recipes)
                    for recipe_to_randomize_name, recipe_to_randomize_pattern in pairs(to_randomize) do
                        if recipes[recipe_to_randomize_name] then
                            if recipes_not_to_randomize[recipe_to_randomize_name] then
                                new_resources.calculate(recipes[recipe_to_randomize_name], technology_name, technology.allowed, technology.recipes)
                            else
                                local randomization_allowed = true
                                if dependencies == "branched" then
                                    randomization_allowed = false
                                    for pre_tech, _ in pairs(technology.allowed) do
                                        if new_resources.has_category(recipes[recipe_to_randomize_name].category, pre_tech) then
                                            randomization_allowed = true
                                            break
                                        end
                                    end
                                end
                                if randomization_allowed then
                                    -- RANDOMIZE
                                    randomized[recipe_to_randomize_name] = true
                                    local randomized_recipe = randomize(recipe_to_randomize_name, technology.allowed, recipe_to_randomize_pattern)
                                    new_resources.calculate(randomized_recipe, technology_name, technology.allowed, technology.recipes)
                                    data.raw.recipe[recipe_to_randomize_name] = prepare.final_recipe(randomized_recipe, data.raw.recipe[recipe_to_randomize_name])
                                    waiting_for_category[recipe_to_randomize_name] = nil
                                else
                                    waiting_for_category[recipe_to_randomize_name] = recipe_to_randomize_pattern
                                end
                            end
                        end
                    end
                    if dependencies == "branched" then
                        for recipe_name, recipe_pattern in ipairs(waiting_for_category) do
                            local randomization_allowed = false
                            for pre_tech, _ in pairs(technology.allowed) do
                                if new_resources.has_category(recipes[recipe_name].category, pre_tech) then
                                    randomization_allowed = true
                                    break
                                end
                            end
                            if randomization_allowed then
                                -- RANDOMIZE
                                randomized[recipe_name] = true
                                local randomized_recipe = randomize(recipe_name, technology.allowed, recipe_pattern)
                                new_resources.calculate(randomized_recipe, technology_name, technology.allowed, technology.recipes)
                                data.raw.recipe[recipe_name] = prepare.final_recipe(randomized_recipe, data.raw.recipe[recipe_name])
                                waiting_for_category[recipe_name] = nil
                            end
                        end
                    end
                end
            end
        end
    end

    -- RANDOMIZE WITHOUT DEPENDENCIES
    if dependencies == "none" then
        for n, t in search.tech(tech, true) do
            random.shuffle(t.recipes)
            for _, r in pairs(t.recipes) do
                if not randomized[r] and recipes[r] then
                    if recipes_not_to_randomize[r] then
                        new_resources.calculate(recipes[r], t.allowed, t.recipes)
                    else
                        randomized[r] = true
                        local new = randomize(r, t.allowed)
                        new_resources.calculate(new, n, t.allowed, t.recipes)
                        data.raw.recipe[r] = prepare.final_recipe(new, data.raw.recipe[r])
                    end
                end
            end
        end
    end
    log("RANDOMIZING DONE!")

    -- RECYCLING
    if mods["quality"] and hidden == "calculate" then
        require("__quality__.data-updates")
        log("RECALCULATED RECYCLING RECIPES.")
    end

    -- CHECK MISSING AGAIN
    local not_calculated = old_resources.all_not_calculated()
    local unlocked_items = old_resources.get_unlocked_items()
    local missing_recipes = missing_check.prepare_recipes(not_calculated, unlocked_items)
    if next(missing_recipes) then
        missing = missing_check.resources(not_calculated, default_values, unlocked_items)
        if missing then
            log("\nMISSING RESOURCES:\n" .. missing)
            data:extend{bigpack(util.data_missing, missing)}
        else
            local missing_formatted = missing_check.format_recipes(missing_recipes, recipes, unlocked_items, category_unlocks)
            data:extend{bigpack(util.data_recipes, table.concat(missing_formatted, "\n"))}
        end
    end
else
    log("\nMISSING RESOURCES:\n" .. missing)
    data:extend{bigpack(util.data_missing, missing)}
end
