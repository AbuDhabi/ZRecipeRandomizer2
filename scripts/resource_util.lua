local F = {}

function F.multiply(comp, mult)
    local r = table.deepcopy(comp)
    for key, value in pairs(r) do
        if key ~= "complexity" then
            r[key] = value * mult
        end
    end
    return r
end

function F.add(to, what)
    local r = table.deepcopy(to)
    if what == nil then
        return r
    end
    for key, amt in pairs(what) do
        if key == "complexity" then
            if r[key] then
                if r[key] < amt then
                    r[key] = amt
                end
            else
                r[key] = amt
            end
        else
            if r[key] then
                r[key] = r[key] + amt
            else
                r[key] = amt
            end
        end
    end
    return r
end

function F.subtract(from, what)
    local r = table.deepcopy(from)
    if what == nil then
        return r
    end
    for key, amt in pairs(what) do
        if key ~= "complexity" then
            if r[key] then
                r[key] = r[key] - amt
            else
                r[key] = - amt
            end
        end
    end
    return r
end

function F.simplify_recipe(r)
    local new = {ing={}, ia = 0, res = {}, ra = 0, removed_ings = {}}
    for name, amount in pairs(r.ing) do
        new.ing[name] = amount
        new.ia = new.ia + 1
    end
    for name, amount in pairs(r.res) do
        if new.ing[name] then
            if math.abs(amount - new.ing[name]) < 1e-6 then
                new.ing[name] = nil
                new.removed_ings[name] = true
                new.ia = new.ia - 1
            elseif amount > new.ing[name] then
                local amt = amount - new.ing[name]
                new.ing[name] = nil
                new.removed_ings[name] = true
                new.res[name] = amt
                new.ia = new.ia - 1
                new.ra = new.ra + 1
            else
                new.ing[name] = new.ing[name] - amount
            end
        elseif amount > 1e-6 then
            new.res[name] = amount
            new.ra = new.ra + 1
        end
    end
    new.ing.time = nil
    new.res.time = nil
    new.ing.complexity = nil
    new.res.complexity = nil
    new.time = r.time
    new.complexity = r.complexity
    new.category = r.category
    return new
end

function F.merge_recipes(a, b, greedy)
    if not a then
        return
    end
    local old = table.deepcopy(a)
    local mult = nil
    for ing, ing_a in pairs(old.ing) do
        if b.res[ing] then
            local m = ing_a / b.res[ing]
            if mult == nil then
                mult = m
            elseif greedy and mult < m then
                mult = m
            elseif not greedy and mult > m then
                mult = m
            end
        end
    end
    if not mult then
        return
    end
    for res, res_a in pairs(b.res) do
        if old.res[res] then
            old.res[res] = old.res[res] + res_a * mult
        else
            old.res[res] = res_a * mult
        end
    end
    for ing, ing_a in pairs(b.ing) do
        if old.ing[ing] then
            old.ing[ing] = old.ing[ing] + ing_a * mult
        else
            old.ing[ing] = ing_a * mult
        end
    end
    old.ing.value = nil
    old.res.value = nil
    old.complexity = math.max(old.complexity, b.complexity)
    old.time = math.min(old.time, b.time * mult)
    old.category = nil
    local r = F.simplify_recipe(old)
    return r
end


function F.trim_negatives(r)
    local h = table.deepcopy(r)
    for key, amt in pairs(h) do
        if amt <= 0 then
            h[key] = nil
        end
    end
    return h
end

function F.fits(what, into)
    for key, amt in pairs(what) do
        if amt > 0 and (not into[key] or amt > into[key]) then
            return false
        end
    end
    return true
end

function F.fits_amt(what, into)
    local ret = math.huge
    for key, amt in pairs(what) do
        if not into[key] then
            if amt > 0 then
                return 0
            end
        else
            local m = into[key] / amt
            if m <= 0 then
                return 0
            end
            if m < ret then
                ret = m
            end
        end
    end
    return math.floor(ret)
end

return F