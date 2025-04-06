local id = require "scripts.id"
local resource_util = require "scripts.resource_util"
local values = require "scripts.values"

local not_random_ores = settings.startup["z-randomizer-not-random-ore-processing"].value

local F = {}

local raw = {}
local default = {}
local waiting = {}
local prepared = {}
local unlocked_items = {}
local unlocked_categories = {}
local category_unlocks = {}
local tech_defaults = {}
local item_defaults = {}

local dont_randomize_ingredients = nil
local recipes = nil

local queue = {q = {}, a = {}, i = 0, s = 0}

local calculated = {}
local calcs = {}
local current_tech = nil
local current_recipes = {}

F.base_raw = {value = 0}

function F.init(defaults, default_categories, cat_unlocks, d_r_i, rs)
    current_tech = values.default_tech_name
    dont_randomize_ingredients = d_r_i
    recipes = rs
    unlocked_categories = table.deepcopy(default_categories)
    category_unlocks = cat_unlocks
    for item, tbl in pairs(defaults) do
        default[item] = tbl.value
        if tbl.tech then
            if not tech_defaults[tbl.tech] then
                tech_defaults[tbl.tech] = {}
            end
            tech_defaults[tbl.tech][#tech_defaults[tbl.tech] + 1] = {item = item, value = tbl.value}
        elseif tbl.items then
            item_defaults[#item_defaults + 1] = {locks = table.deepcopy(tbl.items), item = item, value = tbl.value}
        else
            F.update(item, {value = tbl.value, complexity = values.default_complexity, [item] = 1}, nil, {}, true)
        end
        F.base_raw[item] = 1 / tbl.value
    end
end

function F.raw(item)
    return raw[item]
end

function F.unlocked_items()
    return unlocked_items
end

function F.all_not_calculated()
    local ret = {}
    for key, value in pairs(prepared) do
        if not calcs[key] then
            ret[key] = value
        end
    end
    return ret
end

local function unlock(item, recipe)
    local un = false
    if not unlocked_items[item] then
        unlocked_items[item] = {}
        un = true
    else
        for _, value in ipairs(current_recipes) do
            if value == recipe then
                un = true
                break
            end
        end
    end
    if un and not unlocked_items[item][current_tech] then
        unlocked_items[item][current_tech] = true
        if category_unlocks[item] then
            for _, cat in pairs(category_unlocks[item]) do
                if not unlocked_categories[cat] then
                    unlocked_categories[cat] = {[current_tech] = true}
                    if waiting["CAT-" .. cat] then
                        for r, rly in pairs(waiting["CAT-" .. cat]) do
                            queue.add(r)
                        end
                    end
                    waiting["CAT-" .. cat] = nil
                else
                    unlocked_categories[cat][current_tech] = true
                end
            end
        end
    end
end

function F.pattern(recipe_name)
    local pattern = {}
    local total_raw = {value = 0, time = 0}
    local changeable = {}
    local recipe = recipes[recipe_name]
    local raws = {}
    if recipe == nil then
        return
    end
    for i = 1, #recipe.ing, 1 do
        local ing = recipe.ing[i]
        local item = id.dot(ing)
        local r = table.deepcopy(raw[item])
        if r and not r.time then
            r.time = 1
        end
        if not r and not prepared[recipe_name].removed_ings[item] then
            return
        end
        if #changeable >= 5 or not r or r.value == 0 or r.value == math.huge or (not_random_ores and string.match(item, "^item%..*%-ore$")) or dont_randomize_ingredients[item] then
            pattern[i] = {type = ing.type, name = ing.name, amount = ing.amount, value = r and r.value or 0}
        else
            changeable[#changeable + 1] = i
            pattern[i] = {type = ing.type, comp = r.complexity, on = ing.name, oa = ing.amount}
            raws[i] = resource_util.multiply(r, ing.amount)
            total_raw = resource_util.add(total_raw, raws[i])
        end
    end
    return {pattern = pattern, raw = total_raw, changeable = changeable, raws = raws}
end

local function recalculate(recipe_name, trace, last_when_loop)

    local r = prepared[recipe_name]

    if r == nil or r.ia == 0 or r.ra == 0 then
        return
    end
    if r.category ~= nil and not unlocked_categories[r.category] then
        if not waiting["CAT-" .. r.category] then
            waiting["CAT-" .. r.category] = {}
        end
        waiting["CAT-" .. r.category][recipe_name] = true
        return
    end

    local comp = {value = 0, time = 4 * r.time, complexity = values.default_complexity}
    local ex = {}
    for name, amt in pairs(r.res) do
        ex[name] = amt
    end
    local ready = true
    for name, amt in pairs(r.ing) do
        local got = raw[name]
        if got then
            if not got.time then
                comp.time = comp.time + amt
            end
            comp = resource_util.add(comp, resource_util.multiply(got, amt))
        else
            ready = false
            break
        end
    end

    for key, _ in pairs(r.ing) do
        if not waiting[key] then
            waiting[key] = {[recipe_name] = true}
        elseif waiting[key][recipe_name] == nil then
            waiting[key][recipe_name] = true
        end
    end

    local ret = resource_util.simplify_recipe({ing = comp, res = ex, time = comp.time, complexity = comp.complexity})
    comp = ret.ing
    comp.time = ret.time / 4
    ret.time = r.time
    comp.complexity = ret.complexity + r.complexity + math.sqrt(r.time)
    ret.complexity = r.complexity
    ex = ret.res
    local ra = ret.ra

    if not trace then
        trace = {recipe_name}
    else
        trace = table.deepcopy(trace)
        if trace[#trace] ~= recipe_name then
            trace[#trace + 1] = recipe_name
        end
    end

    if ready then
        local nn = last_when_loop or recipe_name
        if dont_randomize_ingredients and not calcs[nn] then
            local p = F.pattern(nn)
            if p then
                calcs[nn] = true
                calculated[nn] = p
            end
        end
    end

    local dra = 0
    for res, _ in pairs(ex) do
        if default[res] then
            dra = dra + 1
        end
    end
    local ndra = ra - dra
    if dra > 0 then
        local dv = 0
        for res, amt in pairs(ex) do
            if default[res] then
                dv = dv + amt * default[res]
            end
        end
        local max = comp.value * dra / ra
        if dv > max then
            dv = max
        end
        comp = resource_util.multiply(comp, (comp.value - dv) / comp.value)
    end

    if ndra <= 1 then
        for res, amt in pairs(ex) do
            if not default[res] then
                if not ready then
                    F.update(res, nil, nil, trace)
                elseif r.res[res] then
                    local c = table.deepcopy(comp)
                    c = resource_util.multiply(c, 1 / amt)
                    F.update(res, c, recipe_name, trace)
                end
            end
        end
    else
        local svs = {}
        for res, amt in pairs(ex) do
            if not default[res] then
                if raw[res] then
                    svs[res] = math.min(comp.value / ndra, raw[res].value * amt)
                    if not waiting[res] then
                        waiting[res] = {[recipe_name] = true}
                    elseif waiting[res][recipe_name] == nil then
                        waiting[res][recipe_name] = true
                    end
                end
            end
        end
        for res, amt in pairs(ex) do
            if not default[res] then
                if not ready then
                    F.update(res, nil, nil, trace)
                elseif r.res[res] then
                    local c = table.deepcopy(comp)
                    local mult = c.value
                    for key, value in pairs(svs) do
                        if key ~= res then
                            mult = mult - value
                        end
                    end
                    c = resource_util.multiply(c, mult / c.value / amt)
                    F.update(res, c, recipe_name, trace)
                end
            end
        end
    end
    queue.run()
end

local function recalculate_loop(recipe, trace)
    local loop = nil
    for _, value in ipairs(trace) do
        if loop then
            loop[#loop + 1] = value
        end
        if value == recipe then
            loop = {}
        end
    end
    loop[#loop + 1] = recipe
    local new = table.deepcopy(prepared[recipe])
    for i = #loop - 1, 1, -1 do
        new = resource_util.merge_recipes(new, prepared[loop[i]], true)
    end
    if new and new.ia > 0 and new.ra > 0 then
        local name = table.concat(loop, ".")
        prepared[name] = new
        queue.add(name, nil, recipe)
        return true;
    end
    return false;
end

function F.update(item, new_comp, recipe, trace, override_default)
    if new_comp == nil then
        if raw[item] then
            return
        end
    else
        if new_comp ~= nil and current_tech ~= nil then
            unlock(item, recipe)
        end
        if default[item] and not override_default then
            if raw[item] and raw[item].value * 0.99999 > new_comp.value and dont_randomize_ingredients then
                log(values.get_progress() .. "\nAlternative data for resource " .. item .. ": " .. serpent.line(new_comp))
            end
            if not raw[item].time then
                raw[item].time = new_comp.time
                raw[item].complexity = new_comp.complexity
            elseif raw[item].time > new_comp.time then
                raw[item].time = new_comp.time
                raw[item].complexity = new_comp.complexity
            else
                return
            end
        else
            if not raw[item] then
                raw[item] = new_comp
            elseif raw[item].value * 0.99999 > new_comp.value then
                raw[item] = new_comp
            else
                return
            end
        end
    end
    if waiting[item] and trace then
        for nr, rly in pairs(waiting[item]) do
            if rly then
                local cycle = false
                if #trace > 1 then
                    for _, r in ipairs(trace) do
                        if nr == r then
                            cycle = true
                            break
                        end
                    end
                end
                if cycle then
                    if #string.gsub(table.concat(trace, "."), "[^%.]+", "") < 40 then
                        log(values.get_progress() .. "\nLoop detected: " .. table.concat(trace, " > "))
                        -- waiting[item][nr] = not recalculate_loop(nr, trace)
                    else
                        waiting[item][nr] = true
                    end
                else
                    queue.add(nr, trace)
                end
            end
        end
    end
end

local function prepare(recipe)
    local rec = {ing = {}, res = {}}
    for _, v in pairs(recipe.ing) do
        rec.ing[id.dot(v)] = v.amount
    end
    for _, v in pairs(recipe.res) do
        rec.res[id.dot(v)] = v.amount
    end
    local r = resource_util.simplify_recipe(rec)
    r.complexity = r.ia + r.ra * 2 - 3
    r.time = recipe.time
    r.category = recipe.category
    prepared[recipe.name] = r
end

local function unlock_tech_defaults()
    local to_unlock = tech_defaults[current_tech]
    tech_defaults[current_tech] = nil
    if to_unlock then
        for _, tbl in ipairs(to_unlock) do
            F.update(tbl.item, {value = tbl.value, complexity = values.default_complexity, [tbl.item] = 1}, nil, {}, true)
        end
    end
end

local function unlock_item_defaults(allowed)
    for _, tbl in ipairs(item_defaults) do
        local a = true
        local u = false
        for _, item in ipairs(tbl.locks) do
            if F.is_allowed(item, allowed) then
                u = u or F.is_allowed(item, {[current_tech] = true})
            else
                a = false
                break
            end
        end
        if a and (not unlocked_items[tbl.item] or u) then
            F.update(tbl.item, {value = tbl.value, complexity = values.default_complexity, [tbl.item] = 1}, nil, {}, true)
        end
    end
    queue.run()
end

function F.calculate(recipe, technology, allowed, current_rs)
    current_tech = technology
    current_recipes = current_rs
    unlock_tech_defaults()
    calculated = {}
    prepare(recipe)
    recalculate(recipe.name)
    unlock_item_defaults(allowed)
    return calculated
end

function queue.add(recipe_name, trace, last_when_loop)
    if queue.a[recipe_name] then
        queue.q[queue.a[recipe_name]] = nil
    end
    queue.s = queue.s + 1
    queue.q[queue.s] = {recipe_name, trace, last_when_loop}
    queue.a[recipe_name] = queue.s
end

function queue.run()
    if queue.i ~= 0 then
        return
    end
    while queue.i < queue.s do
        queue.i = queue.i + 1
        if queue.q[queue.i] then
            local temp = queue.q[queue.i]
            recalculate(temp[1], temp[2], temp[3])
            queue.q[queue.i] = nil
            queue.a[temp[1]] = nil
        end
    end
    queue.s = 0
    queue.i = 0
end

function F.has_category(cat, tech)
    return unlocked_categories[cat] and unlocked_categories[cat][tech]
end

function F.is_allowed(item, allowed)
    for pre_tech, _ in pairs(allowed) do
        if unlocked_items[item] and unlocked_items[item][pre_tech] then
            return true
        end
    end
    return false
end

function F.recalculate_value(r)
    local value = 0
    for key, amt in pairs(r) do
        if amt > 0 and raw[key] then
            value = value + raw[key].value * amt
        end
    end
    r.value = value
    return r
end

function F.get_all()
    return {raw = raw, default = default, waiting = waiting, prepared = prepared}
end

return F
