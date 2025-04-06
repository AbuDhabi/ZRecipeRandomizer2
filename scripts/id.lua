local F = {}

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

function F.SCI_tech(tech, science)
    local ret = {}
    for s, _ in pairs(science) do
        if tech.science[s] then
            ret[#ret+1] = "T"
        else
            ret[#ret+1] = "F"
        end
    end
    return "SCI..." .. table.concat(ret, "")
end

return F