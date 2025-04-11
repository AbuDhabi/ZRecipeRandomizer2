local random = require "scripts.random"
local resource_util = require "scripts.resource_util"
local util = require "scripts.util"

local F = {}

function F.tech(tech, check_dependencies)
    local to_generate = {}
    local tech_amt = 1
    for n,_ in pairs(tech) do
        if n ~= util.default_tech_name then
            to_generate[tech_amt] = n
            tech_amt = tech_amt + 1
        end
    end
    if not util.tech_amt then
        util.tech_amt = tech_amt
    end
    random.shuffle(to_generate)
    table.insert(to_generate, 1, util.default_tech_name)

    local index = 0
    local attempts = 0
    local c_tech = 1
    local done = {}
    return function()
        if tech_amt > 0 then
            -- loop through techs
            while true do
                index = index + 1
                if index > tech_amt then
                    index = 1
                end
                local n = to_generate[index]
                local t = tech[n]
                local ready = attempts / tech_amt
                -- check prereqs
                if check_dependencies then
                    for _,p in ipairs(t.pre) do
                        if not done[p] then
                            ready = ready - 1
                            if ready < 0 then
                                break
                            end
                        end
                    end
                end
                if ready < 0 then
                    -- not ready
                    attempts = attempts + 1
                else
                    -- ready
                    attempts = 0
                    tech_amt = tech_amt - 1
                    table.remove(to_generate, index)
                    done[n] = true

                    for _, pre in pairs(t.pre) do
                        if tech[pre] then
                            for a, _ in pairs(tech[pre].allowed) do
                                t.allowed[a] = true
                            end
                        end
                    end

                    log("    " .. util.get_progress(c_tech, 0) .. "   Tech " .. c_tech .. " (" .. tech_amt .. " left): " .. n)
                    c_tech = c_tech + 1
                    return n, t
                end
            end
        end
    end
end

function F.ingredient_combinations(old_resources, new_resources, pattern, changeable, recipe, max_raw, max_value, complexity_variance, dont_randomize_ingredients, branched, allowed)
    local max_rr = table.deepcopy(max_raw)
    local min_comp, max_comp = math.huge, 0
    for key, value in pairs(pattern) do
        if value.comp then
            value.min_comp = value.comp - complexity_variance * math.sqrt(value.comp)
            if min_comp > value.min_comp then
                min_comp = value.min_comp
            end
            value.max_comp = value.comp + complexity_variance * math.sqrt(value.comp)
            if max_comp < value.max_comp then
                max_comp = value.max_comp
            end
        end
    end
    max_rr.complexity = max_comp
    local avail = {item={}, fluid={}}
    local cs = {}
    local used = {}
    for key, value in pairs(pattern) do
        if value.name then
            used[util.dot(value)] = true
        end
    end
    for entry, _ in pairs(old_resources.unlocked_items()) do
        if not used[entry] then
            local raw = new_resources.raw(entry)
            if raw and raw.value > 0 and raw.value <= max_value and min_comp <= raw.complexity and max_comp >= raw.complexity and not dont_randomize_ingredients[entry] and not (#recipe.res == 1 and util.dot(recipe.res[1]) == entry) and (not branched or new_resources.is_allowed(entry, allowed)) then
                if resource_util.fits(raw, max_rr) then
                    local type = string.match(entry, "(%a+)%.")
                    avail[type][#avail[type]+1] = entry
                    cs[entry] = raw.complexity
                end
            end
        end
    end
    local pick = {}
    for i, _ in ipairs(changeable) do
        pick[i] = {}
    end
    -- ANTI-ORE PROCEDURE
    local new_avail_item = {}
    if random.int(10) < 10 then
        for _, item in pairs(avail.item) do
            if not string.match(item, "-ore$") then
                table.insert(new_avail_item, item)
            end
        end
        avail.item = new_avail_item
    end

    random.shuffle(avail.item)
    random.shuffle(avail.fluid)
    for t, a in pairs(avail) do
        for _, e in ipairs(a) do
            for i, p in ipairs(changeable) do
                if pattern[p].type == t then
                    if cs[e] >= pattern[p].min_comp and cs[e] <= pattern[p].max_comp then
                        pick[i][#pick[i]+1] = e
                    end
                end
            end
        end
    end

    local is = {}
    local found = {}
    local offsets = {}
    for index, value in ipairs(changeable) do
        is[index] = 0
        offsets[index] = random.int(#pick[index]) - 1
    end
    local depth = 1
    return function()
        while true do
            is[depth] = is[depth] + 1
            if is[depth] > #pick[depth] then
                is[depth] = 0
                if depth == 1 then
                    break
                else
                    depth = depth - 1
                end
            else
                local duplicate = false
                found[depth] = pick[depth][(is[depth] + offsets[depth]) % #pick[depth] + 1]
                for i = 1, depth - 1, 1 do
                    if found[depth] == found[i] then
                        duplicate = true
                        break
                    end
                end
                if not duplicate then
                    if depth < #changeable then
                        depth = depth + 1
                    else
                        local ret = table.deepcopy(pattern)
                        for d, i in ipairs(changeable) do
                            ret[i].string = found[d]
                        end
                        return ret
                    end
                end
            end
        end
    end
end

return F