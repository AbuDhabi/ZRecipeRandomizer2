local id = require "scripts.id"

local F = {}

local missing = {}
local available = {}
local found = {}
local prereqs = {}
local recipes = {}
local stops = {}

local function apply_missing(result, ingredients)
    if next(ingredients) then
        if not missing[result] then
            missing[result] = {}
        end
        missing[result][#missing[result]+1] = ingredients
    else
        missing[result] = nil
        found[result] = true
    end
end

local function apply_available(result)
    available[result] = true
    for m, o in pairs(missing) do
        local ol = #o
        local i = 0
        while i < ol do
            i = i + 1
            local oj = #o[i]
            local j = 0
            while j < oj do
                j = j + 1
                if o[i][j] == result then
                    if oj == 1 then
                        o[i] = nil
                        break
                    else
                        o[i][j] = o[i][oj]
                        o[i][oj] = nil
                        j = j - 1
                        oj = oj - 1
                    end
                end
            end
            if o[i] == nil then
                missing[m] = nil
                break
            end
        end
    end
end

function F.resources(rs, defaults, extra)
    recipes = rs
    missing = {}
    available = {}
    found = {}
    prereqs = {}
    for k, _ in pairs(defaults) do
        found[k] = true
        available[k] = true
    end
    if extra then
        for k, _ in pairs(extra) do
            found[k] = true
            available[k] = true
        end
    end
    stops = table.deepcopy(available)

    for rn, r in pairs(recipes) do
        if not r.ia and #r.ing or r.ia > 0 then
            local to_add = {}
            local to_find = {}
            for n, v in pairs(r.res) do
                if type(n) == "number" then
                    n = id.dot(v)
                end
                if not prereqs[n] then
                    prereqs[n] = {}
                end
                prereqs[n][#prereqs[n]+1] = rn
                if not found[n] then
                    to_add[#to_add+1] = n
                end
                if not available[n] then
                    apply_available(n)
                end
            end
            for n, v in pairs(r.ing) do
                if type(n) == "number" then
                    n = id.dot(v)
                end
                if not available[n] then
                    to_find[#to_find+1] = n
                end
            end
            for _, n in ipairs(to_add) do
                apply_missing(n, to_find)
            end
        end
    end

    if next(missing) then
        local ret = {}
        local changed = true
        while changed do
            changed = false
            for m, o in pairs(missing) do
                if #o == 1 and #o[1] == 1 then
                    ret[#ret+1] = o[1][1]
                    apply_available(o[1][1])
                    changed = true
                    break
                end
            end
        end
        for m, o in pairs(missing) do
            if #o == 1 then
                ret[#ret+1] = table.concat(o[1], "\n")
            else
                for i, value in pairs(o) do
                    o[i] = table.concat(value, " and ")
                end
                ret[#ret+1] = "either  " .. table.concat(o, "\n       or  ")
            end
        end
        return table.concat(ret, "\n")
    else
        return
    end
end

function F.prepare_recipes(not_calculated, unlocked_items)
    local missing_recipes = {}
    for name, r in pairs(not_calculated) do
        if not string.match(name, "%.") and not string.match(name, "#") and r.ia > 0 and r.ra > 0 then
            local s = 0
            for v, _ in pairs(r.ing) do
                if not unlocked_items[v] then
                    s = s + 1
                    local index = "[i]"..v
                    if not missing_recipes[index] then
                        missing_recipes[index] = {}
                    end
                    missing_recipes[index][name] = true
                end
            end
            if s == 0 then
                local index = "[c]"..r.category
                if not missing_recipes[index] then
                    missing_recipes[index] = {}
                end
                missing_recipes[index][name] = true
            end
        end
    end
    return missing_recipes
end

function F.format_recipes(missing_recipes, all_recipes, unlocked_items, category_unlocks)
    local conversions = {}
    for req, value in pairs(missing_recipes) do
        if not conversions[req] then
            conversions[req] = {}
        end
        for rec, _ in pairs(value) do
            for _, res in pairs(all_recipes[rec].res) do
                if not unlocked_items[req] then
                    conversions[req][#conversions[req]+1] = "[i]" .. id.dot(res)
                end
            end
        end
    end
    for item, value in pairs(category_unlocks) do
        local index = "[i]" .. item
        if not unlocked_items[index] then
            if not conversions[index] then
                conversions[index] = {}
            end
            for _, cat in pairs(value) do
                conversions[index][#conversions[index]+1] = "[c]" .. cat
            end
        end
    end
    local changed = table.deepcopy(missing_recipes)
    while next(changed) do
        local new_changed = {}
        for key, _ in pairs(changed) do
            if conversions[key] then
                for _, to_add in pairs(conversions[key]) do
                    if missing_recipes[to_add] then
                        for v, _ in pairs(missing_recipes[to_add]) do
                            if not missing_recipes[key][v] then
                                missing_recipes[key][v] = true
                                new_changed[key] = true
                            end
                        end
                    end
                end
            end
        end
        changed = table.deepcopy(new_changed)
    end

    local sorted_missing = {}
    for key, value in pairs(missing_recipes) do
        local recs = {}
        for r, _ in pairs(value) do
            recs[#recs+1] = r
        end
        if #recs > 0 then
            sorted_missing[#sorted_missing+1] = {missing = key, amount = #recs, recipes = recs}
        end
    end
    table.sort(sorted_missing, function (a, b) return a.amount > b.amount end)
    missing_recipes = {}
    for i, value in ipairs(sorted_missing) do
        missing_recipes[i] = value.amount .. value.missing .. "\n    [r]" .. table.concat(value.recipes, "[r]", 1, math.min(20, value.amount)) .. (value.amount > 20 and "..." or "")
        if i >= 100 then
            break
        end
    end
    if #sorted_missing > 100 then
        missing_recipes[101] = "and " .. (#sorted_missing - 100) .. " more..."
    end
    return missing_recipes
end

return F